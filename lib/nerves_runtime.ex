defmodule Nerves.Runtime do
  require Logger

  @moduledoc """

  """

  @doc """
  Reboot the device and gracefully shutdown the Erlang VM.
  """
  @spec reboot() :: :ok
  def reboot(), do: logged_shutdown "reboot"

  @doc """
  Power off the device.
  """
  @spec poweroff() :: :ok
  def poweroff(), do: logged_shutdown "poweroff"

  @doc """
  Halt the device (meaning hang, not power off, nor reboot).

  Note: this is different than :erlang.halt(), which exits BEAM, and
  may end up rebooting the device if `erlinit.config` settings allow reboot on exit.
  """
  @spec halt() :: :ok
  def halt(), do: logged_shutdown "halt"

  # private helpers

  defp logged_shutdown(cmd) do
    Logger.info "#{__MODULE__} : device told to #{cmd}"

    # Invoke the appropriate command to tell erlinit that a shutdown
    # of the Erlang VM is imminent. Once this returns, the Erlang has
    # about 10 seconds to exit unless `--graceful-powerdown` is used
    # in the `erlinit.config` to modify the timeout.
    System.cmd(cmd, [])

    # Gracefully shut down
    :init.stop
  end

end
