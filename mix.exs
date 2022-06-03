defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  @version "0.11.10"
  @source_url "https://github.com/nerves-project/nerves_runtime"

  def project do
    [
      app: :nerves_runtime,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
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
      extra_applications: [:logger],
      mod: {Nerves.Runtime.Application, []}
    ]
  end

  defp deps do
    [
      {:uboot_env, "~> 1.0 or ~> 0.3.0"},
      {:nerves_logging, "~> 0.1.0"},
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
