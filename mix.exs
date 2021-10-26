defmodule Nerves.Runtime.MixProject do
  use Mix.Project

  @version "0.11.8"
  @source_url "https://github.com/nerves-project/nerves_runtime"

  def project do
    [
      app: :nerves_runtime,
      version: @version,
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      build_embedded: true,
      compilers: [:elixir_make | Mix.compilers()],
      make_targets: ["all"],
      make_clean: ["mix_clean"],
      make_error_message: """
      If the error message above says that libmnl.h can't be found, then the
      fix is to install libmnl. For example, run `apt install libmnl-dev` on
      Debian-based systems.
      """,
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: dialyzer(),
      deps: deps(),
      aliases: [format: [&format_c/1, "format"]],
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
      {:system_registry, "~> 0.8.0"},
      {:uboot_env, "~> 1.0 or ~> 0.3.0"},
      {:elixir_make, "~> 0.6", runtime: false},
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
      files: ["CHANGELOG.md", "lib", "LICENSE", "mix.exs", "README.md", "src/*.[ch]", "Makefile"],
      licenses: ["Apache-2.0"],
      links: %{"Github" => @source_url}
    ]
  end

  defp dialyzer() do
    [
      flags: [:race_conditions, :unmatched_returns, :error_handling, :underspecs]
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
