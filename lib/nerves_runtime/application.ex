defmodule Nerves.Runtime.Application do
  @moduledoc false

  use Application
  require Logger

  alias Nerves.Runtime.{Init, Kernel, KV}
  alias Nerves.Runtime.Log.{KmsgTailer, SyslogTailer}

  @rngd_path "/usr/sbin/rngd"

  @impl true
  def start(_type, _args) do
    # On systems with hardware random number generation, it is important that
    # "rngd" gets started as soon as possible to start adding entropy to the
    # system. So much code directly or indirectly uses random numbers that it's
    # very easy to block on the random number generator or get low entropy
    # numbers.
    try_rngd()

    target = Nerves.Runtime.target()

    children =
      [
        KV
      ] ++ target_children(target)

    opts = [strategy: :one_for_one, name: Nerves.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp target_children("host") do
    []
  end

  defp target_children(_target) do
    kernel_opts = Application.get_env(:nerves_runtime, :kernel, [])

    [
      KmsgTailer,
      SyslogTailer,
      {Kernel.UEvent, kernel_opts},
      Init
    ]
  end

  defp try_rngd() do
    if File.exists?(@rngd_path) do
      # Launch rngd. It daemonizes itself so this should return quickly.
      case System.cmd(@rngd_path, []) do
        {_, 0} ->
          :ok

        {reason, _non_zero_exit} ->
          _ = Logger.warn("Failed to start rngd: #{inspect(reason)}")
          :ok
      end
    else
      :ok
    end
  end
end
