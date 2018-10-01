defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_runtime,
      version: "0.8.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      make_clean: ["clean"],
      compilers: [:elixir_make | Mix.compilers()],
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: [format: [&format_c/1, "format"]],
      dialyzer: [plt_add_apps: [:iex]]
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
      {:elixir_make, "~> 0.4", runtime: false},
      {:ex_doc, "~> 0.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false}
    ]
  end

  defp docs do
    [extras: ["README.md"], main: "readme"]
  end

  defp description do
    """
    Small, general runtime utilities for Nerves devices
    """
  end

  defp package do
    [
      files: ["lib", "LICENSE", "mix.exs", "README.md", "src/*.[ch]", "Makefile"],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/nerves-project/nerves_runtime"}
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
