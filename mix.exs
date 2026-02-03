defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  @version "0.13.12"
  @source_url "https://github.com/nerves-project/nerves_runtime"

  def project do
    [
      app: :nerves_runtime,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      preferred_cli_env: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs},
      aliases: [test: &run_test/1]
    ]
  end

  defp run_test(options) do
    # Because we mock Erlang modules, we need the `-nostick` flag to avoid errors.
    # This restarts Erlang to run tests if called without `ERL_FLAGS`.
    if System.get_env("ERL_FLAGS") == nil do
      System.cmd("mix", ["test" | options],
        into: IO.stream(:stdio, :line),
        env: [{"ERL_FLAGS", "-nostick"}]
      )
    else
      Mix.Task.run("test", options)
    end
  end

  def application do
    [
      env: [
        boardid_path: "/usr/bin/boardid",
        devpath: "/dev/rootdisk0",
        fwup_env: %{},
        fwup_path: "fwup",
        kv_backend: kv_backend(Mix.target()),
        ops_fw_path: "/usr/share/fwup/ops.fw"
      ],
      extra_applications: [:logger],
      mod: {Nerves.Runtime.Application, []}
    ]
  end

  defp kv_backend(:host), do: Nerves.Runtime.KVBackend.InMemory
  defp kv_backend(_target), do: Nerves.Runtime.KVBackend.UBootEnv

  def cli do
    [preferred_envs: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs}]
  end

  defp deps do
    [
      {:uboot_env, "~> 1.0 or ~> 0.3.0"},
      {:nerves_logging, "~> 0.2.0"},
      {:nerves_uevent, "~> 0.1.0"},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false},
      {:credo_binary_patterns, "~> 0.2.2", only: :dev, runtime: false},
      {:mimic, "~> 2.3", only: [:dev, :test]}
    ]
  end

  defp docs do
    [
      extras: ["README.md", "CHANGELOG.md"],
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end

  defp description do
    "Small, general runtime utilities for Nerves devices"
  end

  defp package do
    [
      files: [
        "CHANGELOG.md",
        "lib",
        "LICENSES/*",
        "mix.exs",
        "NOTICE",
        "README.md",
        "REUSE.toml"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md",
        "GitHub" => @source_url,
        "REUSE Compliance" =>
          "https://api.reuse.software/info/github.com/nerves-project/nerves_runtime"
      }
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
    ]
  end
end
