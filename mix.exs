defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_runtime,
      version: "0.6.1",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      make_clean: ["clean"],
      compilers: [:elixir_make | Mix.compilers()],
      description: description(),
      package: package(),
      docs: docs(),
      deps: deps(),
      aliases: [format: [&format_c/1, "format"]]
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {Nerves.Runtime.Application, []}]
  end

  defp deps do
    [
      {:elixir_make, "~> 0.4", runtime: false},
      {:system_registry, "~> 0.5"},
      {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp docs do
    [extras: ["README.md"], main: "readme"]
  end

  defp description do
    """
    Small, general runtime libraries and utilities for Nerves devices
    """
  end

  defp package do
    [
      maintainers: ["Frank Hunleth", "Justin Schneck", "Greg Mefford"],
      files: ["lib", "LICENSE", "mix.exs", "README.md", "src/*.[ch]", "Makefile"],
      licenses: ["Apache 2.0"],
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
