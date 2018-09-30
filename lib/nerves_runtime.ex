defmodule Nerves.Runtime do
  require Logger

  alias Nerves.Runtime.OutputLogger

  # This is provided by all of the official Nerves system images
  @revert_fw_path "/usr/share/fwup/revert.fw"

  @typedoc """
  Options for `Nerves.Runtime.revert/1`.

  * `:reboot` - Call `Nerves.Runtime.reboot/0` after reverting (defaults to `true`)
  """
  @type revert_options :: {:reboot, boolean()}

  @moduledoc """
  Nerves.Runtime contains functions useful for almost all Nerves-based devices.
  """

  @doc """
  Reboot the device and gracefully shutdown the Erlang VM.

  This calls `:init.stop/0` internally. If `:init.stop/0` takes longer than the
  `erlinit.config`'s `--graceful-powerdown` setting (likely 10 seconds) then
  the system will be hard rebooted.
  """
  @spec reboot() :: no_return()
  def reboot(), do: logged_shutdown("reboot")

  @doc """
  Power off the device.

  This calls `:init.stop/0` internally. If `:init.stop/0` takes longer than the
  `erlinit.config`'s `--graceful-powerdown` setting (likely 10 seconds) then
  the system will be hard rebooted.
  """
  @spec poweroff() :: no_return()
  def poweroff(), do: logged_shutdown("poweroff")

  @doc """
  Halt the device (meaning hang, not power off, nor reboot).

  Note: this is different than :erlang.halt(), which exits BEAM, and may end up
  rebooting the device if `erlinit.config` settings allow reboot on exit.
  """
  @spec halt() :: no_return()
  def halt(), do: logged_shutdown("halt")

  @doc """
  Revert the device to running the previous firmware.

  This requires a specially constructed fw file.
  """
  @spec revert([revert_options]) :: :ok | {:error, reason :: any}
  def revert(opts \\ []) do
    reboot? = if opts[:reboot] != nil, do: opts[:reboot], else: true

    if File.exists?(@revert_fw_path) do
      cmd("fwup", [@revert_fw_path, "-t", "revert", "-d", "/dev/rootdisk0"], :info)
      if reboot?, do: reboot()
    else
      {:error, "Unable to locate revert firmware at path: #{@revert_fw_path}"}
    end
  end

  @doc """
  Run system command and log output into logger.
  """
  @spec cmd(binary(), [binary()], :debug | :info | :warn | :error | :return) ::
          {Collectable.t(), exit_status :: non_neg_integer()}
  def cmd(cmd, params, :return), do: System.cmd(cmd, params, stderr_to_stdout: true)

  def cmd(cmd, params, out),
    do: System.cmd(cmd, params, into: OutputLogger.new(out), stderr_to_stdout: true)

  def target() do
    target = Application.get_env(:nerves_runtime, :target)
    if target == "host", do: "host", else: "target"
  end

  # private helpers
  @spec logged_shutdown(String.t()) :: no_return()
  defp logged_shutdown(cmd) do
    try do
      Logger.info("#{__MODULE__} : device told to #{cmd}")

      # Invoke the appropriate command to tell erlinit that a shutdown of the
      # Erlang VM is imminent. Once this returns, the Erlang has about 10
      # seconds to exit unless `--graceful-powerdown` is used in the
      # `erlinit.config` to modify the timeout.
      {_, 0} = cmd(cmd, [], :info)

      # Start a graceful shutdown
      :ok = :init.stop()

      # `:init.stop()` is asynchronous, so sleep longer than it takes to avoid
      # returning.
      Process.sleep(60_000)
    after
      # If anything unexpected happens, call :erlang.halt() to avoid getting
      # stuck in a state where the application thinks it's done.
      :erlang.halt()
    end
  end
end
