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
  cause inadvertent reboots. If using this as a template, consider summarizing
  status in a separate GenServer and checking it here. The Alarmist library may
  be helpful too.
  """

  require Logger

  @give_up_timeout to_timeout(minute: 15)

  @spec register_callback(Keyword.t()) :: :ok
  def register_callback(_opts) do
    :heart.set_callback(__MODULE__, :check)

    # Let Nerves Heart know that the callback was registered so it can reboot if this code somehow was never called.
    Nerves.Runtime.Heart.init_complete()
  end

  @doc false
  def check() do
    cond do
      Nerves.Runtime.firmware_valid?() ->
        :heart.clear_callback()
        :ok

      :init.get_status() == {:started, :started} ->
        Nerves.Runtime.validate_firmware()
        Logger.info("Nerves.Runtime.AutoValidate: Firmware validated")
        :ok

      give_up?() ->
        Logger.error(
          "Nerves.Runtime.AutoValidate: Firmware validation condition never happened. Giving up and rebooting"
        )

        :error

      true ->
        Logger.debug(
          "Nerves.Runtime.AutoValidate: Init is not done yet. Trying again shortly. Current status: #{inspect(:init.get_status())}"
        )

        :ok
    end
  end

  defp give_up?() do
    {total, _last_call} = :erlang.statistics(:wall_clock)
    total > @give_up_timeout
  end
end
