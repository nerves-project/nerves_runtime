defmodule Nerves.Runtime.Mixfile do
  use Mix.Project

  def project do
    [app: :nerves_runtime,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     make_clean: ["clean"],
     compilers: [:elixir_make | Mix.compilers],
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Nerves.Runtime.Application, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:elixir_make, "~> 0.3", runtime: false},
     {:gen_stage, "~> 0.4"},
     {:nerves_uart, "~> 0.1.0", optional: true}]
  end
end
