# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.AutoValidate do
  @moduledoc """
  GenServer that validates firmware once the release script succeeds

  This module provides an easy option for validating firmware for simple
  use cases. Whether new firmware even needs to be validated on first boot
  is determined by the Nerves system that you're using. When it doubt, an
  easy way to know is if you have to run `Nerves.Runtime.validate_firmware/0`
  every time you upload new firmware, then your Nerves system requires
  validation. While you may eventually want to check that networking or other
  things work before validating, using this module should suffice in the mean time.

  To enable this, add the following to your `config.exs`:

  ```elixir
  config :nerves_runtime, auto_validate_firmware: true
  ```
  """
  use GenServer
  require Logger

  @check_interval to_timeout(second: 10)
  @giveup_timeout to_timeout(minute: 15)

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    if opts[:auto_validate_firmware] == true and not Nerves.Runtime.firmware_valid?() do
      _ = :timer.send_interval(@check_interval, :check)
      _ = Process.send_after(self(), :give_up, @giveup_timeout)
      {:ok, nil}
    else
      :ignore
    end
  end

  @impl GenServer
  def handle_info(:check, state) do
    status = :init.get_status()

    cond do
      status == {:started, :started} ->
        Nerves.Runtime.validate_firmware()
        Logger.info("Nerves.Runtime.AutoValidate: Firmware validated")
        {:stop, :normal, state}

      Nerves.Runtime.firmware_valid?() ->
        Logger.info("Nerves.Runtime.AutoValidate: Firmware validated elsewhere")
        {:stop, :normal, state}

      true ->
        Logger.debug(
          "Nerves.Runtime.AutoValidate: Init is not done yet. Trying again shortly. Current status: #{inspect(status)}"
        )

        {:noreply, state}
    end
  end

  def handle_info(:give_up, state) do
    Logger.error(
      "Nerves.Runtime.AutoValidate: Firmware validation condition never happened. Giving up and rebooting"
    )

    Nerves.Runtime.reboot()
    {:stop, :normal, state}
  end
end
