defmodule Nerves.Runtime.Power do
  @moduledoc false

  # This module handles the poweroff and reboot operations:
  #
  # It tries to bulletproof issues that can derail a reboot or poweroff sequence
  # from completing. See comments in the code below for details. These have been
  # seen in production.

  alias Nerves.Runtime.Heart

  require Logger

  @dialyzer {:no_return, run_command: 1}

  @typep command() :: :reboot | :poweroff | :halt

  # This is a worst case shutdown timeout. It shouldn't be hit unless shutdown
  # functions take a surprisingly long time.
  @timeout_before_halt :timer.minutes(10)

  # Delegated from Nerves.Runtime
  @doc false
  @spec reboot() :: no_return()
  def reboot(), do: run_command(:reboot)

  # Delegated from Nerves.Runtime
  @doc false
  @spec poweroff() :: no_return()
  def poweroff(), do: run_command(:poweroff)

  # Delegated from Nerves.Runtime
  @doc false
  @spec halt() :: no_return()
  def halt(), do: run_command(:halt)

  # Run a power management command
  #
  # This function doesn't return since the system will power off or reboot
  # shortly after it's called.
  @spec run_command(command()) :: no_return
  defp run_command(cmd) when is_atom(cmd) do
    # Start the shutdown going in a process decoupled from this one, so if
    # some process terminates this one (like a supervisor), the shutdown isn't half completed.
    _ = spawn(fn -> do_run_command(cmd) end)

    # Sleep so that the power management command can complete, but not forever
    # just in case it never completes.
    Process.sleep(@timeout_before_halt)
  after
    # If we get here, exit. Don't try to recover.
    :erlang.halt()
  end

  @spec do_run_command(command()) :: no_return
  defp do_run_command(cmd) do
    Logger.info("#{__MODULE__} : device told to #{cmd}")

    # First try using Nerves Heart to use the watchdog to guard how long it
    # takes to power off or reboot.
    with {:error, _} <- guarded_command(cmd) do
      # If that doesn't work, try invoking Busybox's reboot, shutdown, or halt
      # programs to tell erlinit (PID 1) that a shutdown of the Erlang VM is
      # imminent. Once this returns, Erlang has about 10 seconds to exit unless
      # `--graceful-powerdown` is used in the `erlinit.config` to modify
      # the timeout.

      {_, 0} = Nerves.Runtime.cmd(busybox_command(cmd), [], :info)
    end

    # Start a graceful shutdown
    :ok = :init.stop()

    # Give it time, but don't wait forever.
    Process.sleep(@timeout_before_halt)
  catch
    _, _ ->
      # If any above raised an exception, log and then halt
      Logger.info("#{__MODULE__} : Exception raised when trying to #{cmd}")
  after
    # If we get here, exit. Don't try to recover.
    :erlang.halt()
  end

  defp guarded_command(:halt), do: {:error, :not_implemented}
  defp guarded_command(:poweroff), do: Heart.guarded_poweroff()
  defp guarded_command(:reboot), do: Heart.guarded_reboot()

  defp busybox_command(:halt), do: "halt"
  defp busybox_command(:poweroff), do: "poweroff"
  defp busybox_command(:reboot), do: "reboot"
end
