defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  @version "0.13.7"
  @source_url "https://github.com/nerves-project/nerves_runtime"

  def project do
    [
      app: :nerves_runtime,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      preferred_cli_env: %{docs: :docs, "hex.build": :docs, "hex.publish": :docs}
    ]
  end

  def application do
    [
      env: [
        boardid_path: "/usr/bin/boardid",
        fwup_path: "fwup",
        revert_fw_path: "/usr/share/fwup/revert.fw",
        kv_backend: kv_backend(Mix.target())
      ],
      extra_applications: [:logger],
      mod: {Nerves.Runtime.Application, []}
    ]
  end

  defp kv_backend(:host), do: Nerves.Runtime.KVBackend.InMemory
  defp kv_backend(_target), do: Nerves.Runtime.KVBackend.UBootEnv

  defp deps do
    [
      {:uboot_env, "~> 1.0 or ~> 0.3.0"},
      {:nerves_logging, "~> 0.2.0"},
      {:nerves_uevent, "~> 0.1.0"},
      {:ex_doc, "~> 0.22", only: :docs, runtime: false},
      {:dialyxir, "~> 1.1", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: :dev, runtime: false}
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
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    ]
  end

  defp dialyzer() do
    [
      flags: [:missing_return, :extra_return, :unmatched_returns, :error_handling, :underspecs]
    ]
  end
end
