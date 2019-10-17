defmodule Nerves.Runtime.Application do
  @moduledoc false

  @module_list "/etc/modules"

  use Application
  require Logger

  alias Nerves.Runtime.{Init, Kernel, KV}
  alias Nerves.Runtime.Log.{KmsgTailer, SyslogTailer}

  @rngd_path "/usr/sbin/rngd"

  @impl true
  def start(_type, _args) do
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

    # Kick off startup tasks asynchronously
    spawn(fn -> run_startup_tasks(kernel_opts) end)

    [
      KmsgTailer,
      SyslogTailer,
      {Kernel.UEvent, kernel_opts},
      Init
    ]
  end

  defp run_startup_tasks(opts) do
    # Auto-load hardcoded modules
    if Keyword.get(opts, :autoload_modules, true) do
      load_kernel_modules()
    end

    # On systems with hardware random number generation, it is important that
    # "rngd" gets started as soon as possible to start adding entropy to the
    # system. So much code directly or indirectly uses random numbers that it's
    # very easy to block on the random number generator or get low entropy
    # numbers.
    try_rngd()
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

  defp load_kernel_modules() do
    with {:ok, contents} <- File.read(@module_list) do
      contents
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.each(&process_modules_line/1)
    end
  end

  defp process_modules_line(""), do: :ok
  defp process_modules_line("#" <> _comment), do: :ok

  defp process_modules_line(module_name) do
    case System.cmd("/sbin/modprobe", [module_name]) do
      {_, 0} -> :ok
      _other -> Logger.warn("Error loading module #{module_name}. See #{@module_list}.")
    end
  end
end
