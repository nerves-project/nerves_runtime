defmodule Nerves.Runtime do
  @moduledoc """
  Nerves.Runtime contains functions useful for almost all Nerves-based devices.
  """
  alias Nerves.Runtime.FwupOps
  alias Nerves.Runtime.KV
  alias Nerves.Runtime.OutputLogger
  alias Nerves.Runtime.Power

  require Logger

  # Capture the target that this was built for
  @mix_target Mix.target()

  @doc """
  Reboot the device and gracefully shutdown the Erlang VM.

  This calls `:init.stop/0` internally. If `:init.stop/0` takes longer than the
  `erlinit.config`'s `--graceful-powerdown` setting (likely 10 seconds) then
  the system will be hard rebooted.
  """
  @spec reboot() :: no_return()
  defdelegate reboot(), to: Power

  @doc """
  Power off the device.

  This calls `:init.stop/0` internally. If `:init.stop/0` takes longer than the
  `erlinit.config`'s `--graceful-powerdown` setting (likely 10 seconds) then
  the system will be hard rebooted.
  """
  @spec poweroff() :: no_return()
  defdelegate poweroff(), to: Power

  @doc """
  Halt the device (meaning hang, not power off, nor reboot).

  Note: this is different than :erlang.halt(), which exits BEAM, and may end up
  rebooting the device if `erlinit.config` settings allow reboot on exit.
  """
  @spec halt() :: no_return()
  defdelegate halt(), to: Power

  @doc """
  Return the current and next firmware slots

  Firmware slots are labelled `"a"` and `"b"`. The current slot is the one that
  is actively being used. The next slot is the one that will be used on the
  next reboot.

  Normally options are not passed. See `t:Nerves.Runtime.FwupOps.options/0` for
  modifying the behavior of `fwup`.
  """
  @spec firmware_slot(FwupOps.options()) :: %{current: String.t(), next: String.t()}
  def firmware_slot(opts \\ []) do
    case FwupOps.status(opts) do
      {:ok, status} ->
        status

      {:error, reason} ->
        Logger.error("Using old slot detection due to ops.fw error: #{inspect(reason)}")

        # This should be right for the next slot and right most of the time for
        # the current one.
        active = KV.get("nerves_fw_active") || "a"
        %{current: active, next: active}
    end
  end

  @doc """
  Revert the device to running the previous firmware

  This switches the active firmware slot back to the previous one and then
  reboots. This fails if the slot is empty or partially overwritten to prevent
  accidents. It also requires the revert feature to be implemented in the
  Nerves system that's in use. See `Nerves.Runtime.FwupOps` for how this works.

  Normally options are not passed. See `t:Nerves.Runtime.FwupOps.options/0` for
  modifying the behavior of `fwup`.

  Specifying `reboot: false` is allowed, but be sure to reboot. It's easy to
  get confused if you don't reboot afterwards and do a double revert or
  something else silly.
  """
  @spec revert(FwupOps.options()) :: :ok | {:error, reason :: any} | no_return()
  defdelegate revert(opts \\ []), to: FwupOps

  @doc """
  Return the device's serial number

  Serial number storage is device-specific and configurable. Serial numbers can
  be programmed in one-time programmable locations like in CPU ROM or
  cryptographic elements. They can also be in rewritable locations like a
  U-Boot environment block.

  Nerves uses the [`boardid`](https://github.com/nerves-project/boardid/) by
  default (set `:boardid_path` key in the application environment to another
  program to override). Boardid uses the `/etc/boardid.config` file to
  determine how to read the serial number. Official Nerves systems provide
  reasonable default mechanisms for getting started. Override this file in your
  application's `rootfs_overlay` to customize it.

  This function never raises. If a serial number isn't available for any
  reason, it will return a serial number of `"unconfigured"`.
  """
  @spec serial_number() :: String.t()
  def serial_number() do
    boardid_path = Application.get_env(:nerves_runtime, :boardid_path)
    {serial, 0} = System.cmd(boardid_path, [])
    String.trim(serial)
  catch
    _, _ ->
      "unconfigured"
  end

  @doc """
  Mark the running firmware as valid

  A device cannot receive a new firmware if the current one has not been validated.
  In the official Nerves systems, this typically happens automatically. If you are
  handling the firmware validation in your app, then this function can be used as
  a helper to mark firmware as valid.

  For systems that support automatic reverting, if the firmware is not marked as
  valid, then the next reboot will cause a revert to the old firmware

  Normally options are not passed. See `t:Nerves.Runtime.FwupOps.options/0` for
  modifying the behavior of `fwup`.
  """
  @spec validate_firmware(FwupOps.options()) :: :ok
  def validate_firmware(opts \\ []) do
    with {:error, reason} <- FwupOps.validate(opts) do
      Logger.error("Using old validation logic due to ops.fw error: #{inspect(reason)}")

      # If using U-Boot's bootcount feature, set those variables as well
      if KV.get("upgrade_available") do
        KV.put(%{"upgrade_available" => "0", "bootcount" => "0", "nerves_fw_validated" => "1"})
      else
        KV.put("nerves_fw_validated", "1")
      end
    end
  end

  @doc """
  Return whether the firmware has been marked as valid

  Since "valid" means that the next boot will run the same firmware, this also
  returns `true` if firmware validation isn't in use.

  See `validate_firmware/0` for more information.
  """
  @spec firmware_valid?() :: boolean()
  def firmware_valid?() do
    case validation_status() do
      :validated -> true
      :unvalidated -> false
      :unknown -> true
    end
  end

  defp validation_status() do
    with :unknown <- u_boot_bootcount_status() do
      nerves_validated_status()
    end
  end

  defp u_boot_bootcount_status() do
    case KV.get("upgrade_available") do
      "0" -> :validated
      "1" -> :unvalidated
      _ -> :unknown
    end
  end

  defp nerves_validated_status() do
    # Try the slot-specific validation status and then fall back to the global flag
    raw_status = KV.get_active("nerves_fw_validated") || KV.get("nerves_fw_validated")

    case raw_status do
      "1" -> :validated
      "0" -> :unvalidated
      _ -> :unknown
    end
  end

  @doc """
  Run system command and log output into logger.

  NOTE: Unlike System.cmd/3, this does not raise if the executable isn't found
  """
  @spec cmd(binary(), [binary()], :debug | :info | :warn | :error | :return) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(cmd, params, log_level_or_return) do
    case System.find_executable(cmd) do
      nil ->
        Logger.error(
          "Executable #{cmd} was not found. The Nerves System must be fixed to include it!"
        )

        {"", 255}

      cmd_path ->
        run_cmd(cmd_path, params, log_level_or_return)
    end
  end

  defp run_cmd(cmd, params, :return), do: System.cmd(cmd, params, stderr_to_stdout: true)

  defp run_cmd(cmd, params, out),
    do: System.cmd(cmd, params, into: OutputLogger.new(out), stderr_to_stdout: true)

  @doc """
  Return the mix target that was used to build this firmware

  If you're running on the development machine, this will return `:host`.
  If not, it will return whatever the user specified with the `MIX_TARGET`
  environment variable when building this firmware.
  """
  @dialyzer {:nowarn_function, mix_target: 0}
  @spec mix_target() :: atom()
  def mix_target(), do: @mix_target
end
