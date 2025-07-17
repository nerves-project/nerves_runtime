# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.AutoValidate do
  @moduledoc """
  Validates firmware once the release script succeeds

  This module provides an easy option for validating firmware for simple use
  cases. Whether new firmware even needs to be validated on first boot is
  determined by the Nerves system that you're using. When it doubt, an easy way
  to know is if you have to run `Nerves.Runtime.validate_firmware/0` every time
  you upload new firmware, then your Nerves system requires validation. While
  you may eventually want to check that networking or other things work before
  validating, using this module should suffice in the mean time.

  ## Setup

  Add the following to your project's `target.exs` or `config.exs`:

  ```elixir
  config :nerves_runtime, auto_validate_firmware: true
  ```

  Add the following to your project's `rel/vm.args.eex`:

    ```text
  ## Require an initialization handshake within 10 minutes
  -env HEART_INIT_TIMEOUT 600
  ```

  The discussion below explains more about the heart initialization handshake
  timer.

  ## Discussion

  Here's the high level summary:

  1. New firmware is unvalidated on first boot. If it's not validated, it
     reverts back.
  2. This module considers firmware good if the OTP release scripts run to
     completion. A period check runs until it succeeds and then calls
     `Nerves.Runtime.validate_firmware/0`.
  3. If the check does not succeed after 15 minutes, then the device is
     rebooted so that the previous firmware gets run.
  4. If the firmware is so bad that it reboots on its own before 15 minutes, it
     will go back to the previous firmware.

  This sounds good, but broken firmware can also hang or not call the code that
  gives up after 15 minutes.

  Protecting against hung code eventually leads to making use of a hardware
  watchdog. Most Nerves systems use these and integrate it with the Erlang
  heart feature. The hardware watchdog is still a last resort, so other systems
  can certainly try to gracefully reboot before the hardware watchdog kicks in.

  This module registers with Erlang's heart. The
  `Nerves.Runtime.Heart.init_complete/0` call is a Nerves extension to heart to
  cancel a timer on setting the Erlang heart callback. This addresses hangs
  before setting the callback or just something skipping the code entirely.

  Once the system is known to be running on valid firmware, the code
  unregisters the heart callback and is unused.

  Perfection here is so hard since code finds a way.

  Keep in mind that the heart callback is totally unforgiving to errors and
  function calls taking too long. Making it too complicated can backfire and
  cause inadvertent reboots. Rebooting too quickly on errors can impact your
  ability debug partial failures. If using this code as a template, it's
  highly recommended to delegate the complexity to a separate, supervised
  GenServer that can be polled, but protect the call to the poll function.
  """

  use Task, restart: :transient
  require Logger

  @retry_delay to_timeout(second: 10)
  @give_up_minutes 15
  @start_warning_minutes 2

  @doc false
  @spec start_link(keyword()) :: {:ok, pid()}
  def start_link(opts) do
    Task.start_link(__MODULE__, :run, [opts])
  end

  @doc false
  @spec run(keyword()) :: :ok
  def run(_opts) do
    # Register with heart to bullet proof against hangs or other weirdness happening
    # in this code.
    :heart.set_callback(__MODULE__, :heart_check)
    Nerves.Runtime.Heart.init_complete()

    # Wait for all of the applications specified in the release to start.
    {:ok, expected_apps} = repeat_while(&Nerves.Runtime.get_expected_started_apps/0, :error)
    repeat_until(fn -> all_applications_started?(expected_apps) end)

    # Try getting the firmware validation status. If :unknown, hope.
    status = repeat_while(&Nerves.Runtime.firmware_validation_status/0, :unknown)

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

  defp repeat_until(fun) do
    if !fun.() do
      Process.sleep(@retry_delay)
      repeat_until(fun)
    end
  end

  defp repeat_while(fun, unwanted_result) do
    result = fun.()

    if result == unwanted_result do
      Process.sleep(@retry_delay)
      repeat_while(fun, unwanted_result)
    else
      result
    end
  end

  @doc false
  @spec heart_check() :: :ok | :error
  def heart_check() do
    uptime_minutes = get_uptime_minutes()

    do_heart_check(uptime_minutes)
  end

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
