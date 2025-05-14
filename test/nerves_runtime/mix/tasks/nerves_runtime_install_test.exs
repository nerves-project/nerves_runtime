defmodule NervesRuntime.InstallTest do
  use ExUnit.Case, async: true

  import Igniter.Test

  test "installer adds nerves_runtime to shoehorn init in target.exs if missing when config exists" do
    test_project(
      files: %{
        "config/target.exs" => """
        import Config

        config :shoehorn, init: [:foo]
        """
      }
    )
    |> Igniter.compose_task("nerves_runtime.install", [])
    |> assert_has_patch("config/target.exs", ~S"""
     1 1   |import Config
     2 2   |
     3   - |config :shoehorn, init: [:foo]
       3 + |config :shoehorn, init: [:nerves_runtime, :foo]
    """)
  end

  test "installer adds nerves_runtime to to shoehorn init for target.exs by default" do
    test_project()
    |> Igniter.compose_task("nerves_runtime.install", [])
    |> assert_creates("config/target.exs", ~S"""
    import Config
    config :shoehorn, init: [:nerves_runtime]
    """)
  end

  test "installer adds KV backend config to host.exs" do
    test_project(
      files: %{
        "config/host.exs" => """
        import Config
        """
      }
    )
    |> Igniter.compose_task("nerves_runtime.install", [])
    |> assert_has_patch("config/host.exs", ~S"""
      1  1   |import Config
      2  2   |
         3 + |config :nerves_runtime,
         4 + |  kw_backend:
         5 + |    {Nerves.Runtime.KVBackend.InMemory,
         6 + |     contents: %{
         7 + |       "a.nerves_fw_architecture" => "generic",
         8 + |       "a.nerves_fw_description" => "N/A",
         9 + |       "a.nerves_fw_platform" => "host",
        10 + |       "a.nerves_fw_version" => "0.0.0",
        11 + |       "nerves_fw_active" => "a"
        12 + |     }}
        13 + |
    """)
  end
end
