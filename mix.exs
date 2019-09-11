defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_runtime,
      version: "0.10.2",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["clean"],
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: [format: [&format_c/1, "format"]]
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
      {:system_registry, "~> 0.5"},
      {:elixir_make, "~> 0.6", runtime: false},
      {:uboot_env, "~> 0.1"},
      {:ex_doc, "~> 0.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [extras: ["README.md"], main: "readme"]
  end

  defp description do
    "Small, general runtime utilities for Nerves devices"
  end

  defp package do
    [
      files: ["lib", "LICENSE", "mix.exs", "README.md", "src/*.[ch]", "Makefile"],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/nerves-project/nerves_runtime"}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp format_c([]) do
    astyle =
      System.find_executable("astyle") ||
        Mix.raise("""
        Could not format C code since astyle is not available.
        """)

    System.cmd(astyle, ["-n", "-r", "src/*.c", "src/*.h"], into: IO.stream(:stdio, :line))
  end

  defp format_c(_args), do: true
end
