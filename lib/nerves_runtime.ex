defmodule Nerves.Runtime do
  require Logger

  alias Nerves.Runtime.OutputLogger

  @revert_fw_path "/usr/share/fwup/revert.fw"

  @moduledoc """

  """

  @doc """
  Reboot the device and gracefully shutdown the Erlang VM.
  """
  @spec reboot() :: :ok
  def reboot(), do: logged_shutdown("reboot")

  @doc """
  Power off the device.
  """
  @spec poweroff() :: :ok
  def poweroff(), do: logged_shutdown("poweroff")

  @doc """
  Halt the device (meaning hang, not power off, nor reboot).

  Note: this is different than :erlang.halt(), which exits BEAM, and
  may end up rebooting the device if `erlinit.config` settings allow reboot on exit.
  """
  @spec halt() :: :ok
  def halt(), do: logged_shutdown("halt")

  @doc """
  Revert the device to running the previous firmware.

  This requires a specially constructed fw file.
  """
  @spec revert([any]) :: :ok | {:error, reason :: any}
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

  # private helpers

  defp logged_shutdown(cmd) do
    Logger.info("#{__MODULE__} : device told to #{cmd}")

    # Invoke the appropriate command to tell erlinit that a shutdown
    # of the Erlang VM is imminent. Once this returns, the Erlang has
    # about 10 seconds to exit unless `--graceful-powerdown` is used
    # in the `erlinit.config` to modify the timeout.
    cmd(cmd, [], :info)

    # Gracefully shut down
    :init.stop()
  end
end
