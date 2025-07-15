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

  require Logger

  @start_warning_minutes 2
  @give_up_minutes 15

  @warned_key Module.concat(__MODULE__, "Warned")
  @cache_key Module.concat(__MODULE__, "Cache")

  @spec register_callback(Keyword.t()) :: :ok
  def register_callback(_opts) do
    if :heart.set_callback(__MODULE__, :check) == :ok do
      # Let Nerves Heart know that the callback was registered successfully
      Nerves.Runtime.Heart.init_complete()
    else
      Logger.error("Unexpected error registering heart callback. System may reboot when heart's init handshake expires.")
    end

    :ok
  end

  @doc false
  def check() do
    uptime_minutes = get_uptime() |> div(to_timeout(minute: 1))

    cond do
      :init.get_status() == {:started, :started} && broken_apps() == [] ->
        validate_if_needed()
        :ok

      uptime_minutes >= @give_up_minutes ->
        Logger.error("Giving up and rebooting due to unstarted apps #{inspect(broken_apps())}")

        :error

      uptime_minutes > @start_warning_minutes and Process.get(@warned_key) != uptime_minutes ->
        Logger.warning(
          "System not healthy due to unstarted apps: #{inspect(broken_apps())} Check logs. Rebooting in #{@give_up_minutes - uptime_minutes} minutes if unfixed"
        )

        Process.put(@warned_key, uptime_minutes)
        :ok

      true ->
        # Try again later
        :ok
    end
  end

  defp validate_if_needed() do
    if Nerves.Runtime.firmware_validation_status() == :validated do
      # Need to call in another thread since we're currently in the heart
      # process.
      Logger.debug("Firmware validation confirmed")
      spawn(&:heart.clear_callback/0)
      Process.put(@warned_key, nil)
      Process.put(@cache_key, nil)
      :ok
    else
      result = Nerves.Runtime.validate_firmware()

      if result == :ok do
        Logger.info("Firmware validated")
      else
        Logger.error("Firmware validation failed! (#{inspect(result)})")
      end
    end
  end

  defp get_uptime() do
    {total, _last_call} = :erlang.statistics(:wall_clock)
    total
  end

  defp broken_apps() do
    with {:ok, expected} <- cached(&get_expected_started_apps/0) do
      expected -- actual_started_apps()
    end
  end

  defp cached(fun) do
    with r when r in [nil, :error] <- Process.get(@cache_key) do
      result = fun.()
      Process.put(@cache_key, result)
      result
    end
  end

  defp get_expected_started_apps() do
    {:ok, [[boot]]} = :init.get_argument(:boot)
    contents = File.read!("#{boot}.boot")
    {:script, _name, instructions} = :erlang.binary_to_term(contents)

    apps = for {:apply, {:application, :start_boot, [app | _]}} <- instructions, do: app
    {:ok, apps}
  rescue
    _ -> :error
  end

  defp actual_started_apps() do
    for {app, _, _} <- Application.started_applications(), do: app
  end
end
