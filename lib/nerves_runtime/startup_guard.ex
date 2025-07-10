# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.StartupGuard do
  @moduledoc """
  Monitor system startup and validate firmware

  This module provides a default for preventing devices that have failed to
  complete initialization from either reverting to an earlier firmware or
  rebooting to try again. Enough time is given so that a device doesn't get
  into an undebuggable boot loop, but also doesn't wait forever in a state that
  may also be impossible to debug.

  This is a generic default that is intended to be suitable for all use cases.
  However, you will eventually find that you can do better, and you are
  encouraged to replace it when ready. For example, you may want to confirm
  connectivity to a firmware update server before validating a new image just
  in case a change broke networking. Please investigate using alarms (via
  `:alarm_handler` or `alarmist`) for aggregating these checks.

  If your Nerves system requires that new firmware images are validated, you
  will need this. In other words, if you have to run
  `Nerves.Runtime.validate_firmware/0` every time you upload new firmware, then
  your Nerves system requires validation.

  ## Setup

  Add the following to your project's `target.exs` or `config.exs`:

  ```elixir
  config :nerves_runtime, startup_guard_enabled: true
  ```

  To handle a case where Erlang starts fine, but somehow hangs before `StartupGuard` can
  register itself with Erlang's heart feature, there's a handshake that needs to occur.
  The handshake needs to be enabled in Nerves Heart (which integrates with
  Erlang heart), though. To do this, add the following to your project's
  `rel/vm.args.eex`:

  ```text
  ## Require an initialization handshake within 10 minutes
  -env HEART_INIT_TIMEOUT 600
  ```

  ## Further discussion

  Here's the high level summary of how this works:

  1. On init, OTP starts up all applications. When it starts up
    `:nerves_runtime`, `StartupGuard` gets run.
  2. `StartupGuard` registers a `:heart` callback. The callback is a time bomb
     that starts failing after 15 minutes.
  3. `StartupGuard` gets the list of OTP applications that should be started.
     Applications marked in the Mix release to only `:load` aren't counted.
  4. `StartupGuard` waits for all expected applications to start
  5. Once everything starts, `StartupGuard` validates the firmware and removes
     the `:heart` callback.
  6. If anything went wrong, log the errors. Since the `:heart` callback is
     still registered, the system will be available for debugging, but it will
     eventually reboot.

  One nice alteration to this is to leave the `:heart` callback in place, but
  have it check some kind of "system ok" flag. If you do this, keep in mind
  that the callback is totally unforgiving to errors and function calls taking
  too long. Making it too complicated can backfire and cause inadvertent
  reboots. Rebooting too quickly on errors can impact your ability to debug
  partial failures. If using this code as a template, try to keep your code in
  `Task` or change this to a `GenServer` or anything else that can be
  supervised. Decoupling the checks into alarms is another nice pattern.

  ## Troubleshooting

  1. If getting the log message about exceeding the number of retries for
     getting firmware validation status, then
     `Nerves.Runtime.firmware_validation_status/0 is returning `:unknown`. This
     is probably due to the Nerves system's `fwup.conf` not
     initializing `<slot>.nerves_fw_validated` to `0` (or `1` if always valid).
  2. If falling back without logs, try installing `ramoops_logger` to capture
     log messages that don't make it to disk.
  """
  use Task, restart: :transient

  alias Nerves.Runtime.Heart

  require Logger

  # Wait 10s between every check that gets retried
  @retry_delay :timer.seconds(10)

  # Reboot at the 15 minute mark if anything doesn't succeed
  @give_up_minutes 15

  # Start complaining after 2 minutes
  @start_warning_minutes 2

  @doc false
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts) do
    Task.start_link(__MODULE__, :run, [opts])
  end

  @doc false
  @spec run(keyword()) :: :ok
  def run(opts) do
    # The unit tests modify the retry_delay so they can run in a reasonable amount of time
    retry_delay = Keyword.get(opts, :retry_delay, @retry_delay)

    # Register with heart to bulletproof against hangs or other weirdness happening
    # in this code.
    :ok = :heart.set_callback(__MODULE__, :heart_check)
    Heart.init_complete()

    # Wait for all of the applications specified in the release to start.
    {:ok, expected_apps} =
      repeat_while(
        &Nerves.Runtime.get_expected_started_apps/0,
        :error,
        10,
        retry_delay,
        "getting expected apps"
      )

    repeat_until(
      fn -> all_applications_started?(expected_apps) end,
      10,
      retry_delay,
      "waiting for apps to start"
    )

    # Try getting the firmware validation status. If :unknown, hope.
    status =
      repeat_while(
        &Nerves.Runtime.firmware_validation_status/0,
        :unknown,
        10,
        retry_delay,
        "getting firmware validation status"
      )

    # Validate or not.
    if status == :unvalidated do
      Logger.info("Firmware not validated. Validating now...")
      :ok = Nerves.Runtime.validate_firmware()
      Logger.info("Firmware validated successfully")
    else
      Logger.info("Firmware valid and all applications started successfully")
    end

    # Stop the heart callback since all is good now
    :heart.clear_callback()
  end

  defp repeat_until(_fun, 0, _retry_delay, description) do
    raise RuntimeError, "Exceeded maximum retries for #{description}"
  end

  defp repeat_until(fun, retries, retry_delay, description) do
    if !fun.() do
      Process.sleep(retry_delay)
      repeat_until(fun, retries - 1, retry_delay, description)
    end
  end

  defp repeat_while(_fun, _unwanted_result, 0, _retry_delay, description) do
    raise RuntimeError, "Exceeded maximum retries for #{description}"
  end

  defp repeat_while(fun, unwanted_result, retries, retry_delay, description) do
    result = fun.()

    if result == unwanted_result do
      Process.sleep(retry_delay)
      repeat_while(fun, unwanted_result, retries - 1, retry_delay, description)
    else
      result
    end
  end

  # This is registered with :heart in run/1. It's effectively a ticking time
  # bomb. Once registered, it will tell :heart that it's ok until
  # @give_up_minutes go by.  Once run/1 determines that the firmware is valid,
  # it unregisters this so it doesn't blow up.
  @doc false
  @spec heart_check() :: :ok | :error
  def heart_check() do
    uptime_minutes = get_uptime_minutes()

    do_heart_check(uptime_minutes)
  end

  # Only public for unit test purposes
  @doc false
  @spec do_heart_check(non_neg_integer()) :: :ok | :error
  def do_heart_check(uptime_minutes) do
    cond do
      uptime_minutes >= @give_up_minutes ->
        Logger.error("Took too long to validate firmware. Rebooting.")
        :error

      uptime_minutes < @start_warning_minutes ->
        :ok

      uptime_minutes != Process.get(:last_warning_minutes) ->
        Logger.warning(
          "Firmware not validated. Check logs. Rebooting in #{@give_up_minutes - uptime_minutes} minutes if unfixed."
        )

        Process.put(:last_warning_minutes, uptime_minutes)
        :ok

      true ->
        :ok
    end
  end

  defp get_uptime_minutes() do
    {total, _last_call} = :erlang.statistics(:wall_clock)
    div(total, 60_000)
  end

  defp all_applications_started?(expected_apps) do
    actual_apps = for {app, _, _} <- Application.started_applications(), do: app

    unstarted_apps = expected_apps -- actual_apps

    if unstarted_apps != [] do
      Logger.warning("Waiting on the following applications to start: #{inspect(unstarted_apps)}")
      false
    else
      true
    end
  end
end
