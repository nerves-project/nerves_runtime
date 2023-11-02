defmodule Nerves.Runtime.Application do
  @moduledoc false

  use Application

  alias Nerves.Runtime.KV

  require Logger

  @impl Application
  def start(_type, _args) do
    load_services()

    options = Application.get_all_env(:nerves_runtime)
    children = [{KV, options} | target_children()]

    opts = [strategy: :one_for_one, name: Nerves.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.target() == :host do
    defp target_children(), do: []
    defp load_services(), do: :ok
  else
    defp target_children() do
      [
        NervesLogging.KmsgTailer,
        NervesLogging.SyslogTailer,
        Nerves.Runtime.Init
      ]
    end

    defp load_services() do
      # On systems with hardware random number generation, it is important that
      # "rngd" gets started as soon as possible to start adding entropy to the
      # system. So much code directly or indirectly uses random numbers that it's
      # very easy to block on the random number generator or get low entropy
      # numbers.
      # On systems with no hardware random number generation, or where rngd is
      # not installed, haveged is tried as an alternative.
      try_entropy_generator("rngd") || try_entropy_generator("haveged")

      _ = try_load_sysctl_conf()

      :ok
    end

    defp try_entropy_generator(name) do
      path = "/usr/sbin/#{name}"

      if File.exists?(path) do
        # Launch rngd/haveged. They daemonize themselves so this should return quickly.
        case System.cmd(path, []) do
          {_, 0} ->
            true

          {reason, _non_zero_exit} ->
            Logger.warning("Failed to start #{name}: #{inspect(reason)}")
            false
        end
      else
        false
      end
    end

    defp try_load_sysctl_conf() do
      conf_path = "/etc/sysctl.conf"

      if File.exists?(conf_path) do
        case System.cmd("/sbin/sysctl", ["-p", conf_path]) do
          {_, 0} ->
            :ok

          {reason, _non_zero_exit} ->
            Logger.warning("Failed to run sysctl on #{conf_path}: #{inspect(reason)}")
            {:error, reason}
        end
      else
        {:error, :not_found}
      end
    end
  end
end
