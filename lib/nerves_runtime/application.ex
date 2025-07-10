# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2018 Greg Mefford
# SPDX-FileCopyrightText: 2019 Troels Brødsgaard
# SPDX-FileCopyrightText: 2021 Alex McLain
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.Application do
  @moduledoc false

  use Application

  alias Nerves.Runtime.FwupOps
  alias Nerves.Runtime.KV
  alias Nerves.Runtime.StartupGuard

  if Mix.target() != :host do
    require Logger
  end

  @impl Application
  def start(_type, _args) do
    load_services()

    options = Application.get_all_env(:nerves_runtime)
    init_module = Keyword.get(options, :init_module, Nerves.Runtime.Init)

    startup_guard_children =
      if options[:startup_guard_enabled], do: [{StartupGuard, options}], else: []

    children =
      [{FwupOps, options}, {KV, options}] ++
        startup_guard_children ++ target_children(init_module)

    opts = [strategy: :one_for_one, name: Nerves.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.target() == :host do
    defp target_children(_), do: []
    defp load_services(), do: :ok
  else
    defp target_children(nil) do
      [
        NervesLogging.KmsgTailer,
        NervesLogging.SyslogTailer
      ]
    end

    defp target_children(init_module) do
      [
        NervesLogging.KmsgTailer,
        NervesLogging.SyslogTailer,
        init_module
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
        args = Application.get_env(:nerves_runtime, String.to_atom("#{name}_args"), [])
        # Launch rngd/haveged. They daemonize themselves so this should return quickly.
        case System.cmd(path, args) do
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
