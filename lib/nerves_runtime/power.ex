defmodule Nerves.Runtime.Power do
  @moduledoc false

  # This GenServer handles the poweroff and reboot operations:
  #
  # 1. It serializes calls to reboot and poweroff. First one wins if
  #    multiple processes want reboot simultaneously.
  # 2. It decouples the process that the reboot or poweroff sequence
  #    happens in. This lets supervision trees go down midway through
  #    the poweroff process without killing the process doing the
  #    poweroff.

  use GenServer

  alias Nerves.Runtime.Heart

  require Logger

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  # Delegated from Nerves.Runtime
  @doc false
  @spec reboot() :: no_return()
  def reboot() do
    case Heart.guarded_reboot() do
      :ok ->
        :init.stop()

      _ ->
        run_command("reboot")
    end
  catch
    _, _ -> :erlang.halt()
  end

  # Delegated from Nerves.Runtime
  @doc false
  @spec poweroff() :: no_return()
  def poweroff() do
    case Heart.guarded_poweroff() do
      :ok ->
        :init.stop()

      _ ->
        run_command("poweroff")
    end
  catch
    _, _ -> :erlang.halt()
  end

  # Delegated from Nerves.Runtime
  @doc false
  @spec halt() :: no_return()
  def halt(), do: run_command("halt")

  @doc """
  Run a power management command

  The only valid commands are `"reboot"`, `"poweroff"`, and `"halt"`. This is
  NOT intended to be called directly. Call `Nerves.Runtime.reboot/0`, etc. instead.

  This function doesn't return since the system will power off or reboot
  shortly after it's called.
  """
  @spec run_command(String.t()) :: no_return()
  def run_command(cmd) when is_binary(cmd) do
    GenServer.cast(__MODULE__, cmd)

    # Sleep forever since callers of this function don't expect it to return
    Process.sleep(:infinity)
  end

  @impl GenServer
  def init(_options) do
    {:ok, nil}
  end

  @impl GenServer
  @dialyzer {:nowarn_function, handle_cast: 2}
  def handle_cast(cmd, _state) do
    Logger.info("#{__MODULE__} : device told to #{cmd}")

    # Invoke the appropriate command to tell erlinit that a shutdown of the
    # Erlang VM is imminent. Once this returns, the Erlang has about 10
    # seconds to exit unless `--graceful-powerdown` is used in the
    # `erlinit.config` to modify the timeout.
    {_, 0} = Nerves.Runtime.cmd(cmd, [], :info)

    # Start a graceful shutdown
    :ok = :init.stop()
    {:stop, :normal}
  after
    # If anything unexpected happens, call :erlang.halt() to avoid getting
    # stuck in a state where the application thinks it's done.
    :erlang.halt()
    {:stop, :normal}
  end
end
