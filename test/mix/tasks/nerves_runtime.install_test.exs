# SPDX-FileCopyrightText: 2025 Lars Wikman
# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
# Igniter requires Elixir 1.15 or later
if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.NervesRuntime.InstallTest do
    use ExUnit.Case, async: true

    import Igniter.Test

    alias Nerves.Runtime.KVBackend.InMemory

    @mix_exs_with_shoehorn """
    defmodule Test.MixProject do
      use Mix.Project

      def project do
        [
          app: :test,
          version: "0.1.0",
          elixir: "~> 1.17",
          deps: deps()
        ]
      end

      defp deps do
        [
          {:nerves, "~> 1.10", runtime: false},
          {:shoehorn, "~> 0.9.1"},
          {:nerves_runtime, "~> 0.13.0"}
        ]
      end
    end
    """

    defp install(igniter, argv \\ []) do
      Igniter.compose_task(igniter, "nerves_runtime.install", argv)
    end

    defp nerves_project(files \\ %{}) do
      test_project(
        files:
          Map.merge(
            %{
              "config/host.exs" => "import Config\n",
              "config/target.exs" => "import Config\n"
            },
            files
          )
      )
    end

    describe "host KV backend" do
      test "is added to config/host.exs with the template's comments" do
        nerves_project()
        |> install(["--no-startup-guard"])
        |> assert_content_equals("config/host.exs", """
        import Config

        config :nerves_runtime,
          kv_backend:
            {Nerves.Runtime.KVBackend.InMemory,
             contents: %{
               # The KV store on Nerves systems is typically read from UBoot-env, but
               # this allows us to use a pre-populated InMemory store when running on
               # host for development and testing.
               #
               # https://nerves-runtime.hexdocs.pm/readme.html#using-nerves_runtime-in-tests
               # https://nerves-runtime.hexdocs.pm/readme.html#nerves-system-and-firmware-metadata

               "nerves_fw_active" => "a",
               "a.nerves_fw_architecture" => "generic",
               "a.nerves_fw_description" => "N/A",
               "a.nerves_fw_platform" => "host",
               "a.nerves_fw_version" => "0.0.0"
             }}
        """)
        |> assert_unchanged(["config/config.exs", "mix.exs"])
      end

      test "is added to a config/host.exs that ends with a comment" do
        nerves_project(%{
          "config/host.exs" => """
          import Config

          # Add configuration that is only needed when running on the host here.
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_content_equals("config/host.exs", """
        import Config

        # Add configuration that is only needed when running on the host here.

        config :nerves_runtime,
          kv_backend:
            {Nerves.Runtime.KVBackend.InMemory,
             contents: %{
               # The KV store on Nerves systems is typically read from UBoot-env, but
               # this allows us to use a pre-populated InMemory store when running on
               # host for development and testing.
               #
               # https://nerves-runtime.hexdocs.pm/readme.html#using-nerves_runtime-in-tests
               # https://nerves-runtime.hexdocs.pm/readme.html#nerves-system-and-firmware-metadata

               "nerves_fw_active" => "a",
               "a.nerves_fw_architecture" => "generic",
               "a.nerves_fw_description" => "N/A",
               "a.nerves_fw_platform" => "host",
               "a.nerves_fw_version" => "0.0.0"
             }}
        """)
      end

      test "is added after other config in a config/host.exs that ends with a comment" do
        nerves_project(%{
          "config/host.exs" => """
          import Config

          config :my_app, key: 1

          # Trailing comment
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/host.exs", """
        + |config :nerves_runtime,
        + |  kv_backend:
        """)
      end

      test "a config/host.exs that ends with a comment is unchanged the second time" do
        nerves_project(%{
          "config/host.exs" => """
          import Config

          # Add configuration that is only needed when running on the host here.
          """
        })
        |> install(["--no-startup-guard"])
        |> apply_igniter!()
        |> install(["--no-startup-guard"])
        |> assert_unchanged()
      end

      test "generated config is valid and usable by the InMemory backend" do
        igniter = nerves_project() |> install(["--no-startup-guard"]) |> apply_igniter!()

        contents =
          igniter.rewrite |> Rewrite.source!("config/host.exs") |> Rewrite.Source.get(:content)

        config = Config.Reader.eval!("config/host.exs", contents, env: :dev, target: :host)

        assert {InMemory, opts} = config[:nerves_runtime][:kv_backend]
        assert {:ok, %{"nerves_fw_active" => "a"}} = InMemory.load(opts)
      end

      test "is merged with other nerves_runtime config in config/host.exs" do
        nerves_project(%{
          "config/host.exs" => """
          import Config

          config :nerves_runtime, target: "host"
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/host.exs", """
        + |  kv_backend:
        + |    {Nerves.Runtime.KVBackend.InMemory,
        """)
      end

      test "existing kv_backend config is preserved" do
        nerves_project(%{
          "config/host.exs" => """
          import Config

          config :nerves_runtime,
            kv_backend: {Nerves.Runtime.KVBackend.InMemory, contents: %{"serial" => "1234"}}
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_unchanged()
      end

      test "is not written and a notice is given when there is no config/host.exs" do
        test_project()
        |> install(["--no-startup-guard"])
        |> assert_unchanged()
        |> refute_creates("config/host.exs")
        |> refute_creates("config/target.exs")
        |> assert_has_notice(&(&1 =~ "no config/host.exs found"))
      end

      test "is not written to config/config.exs of a Nerves project without config/host.exs" do
        test_project(files: %{"config/target.exs" => "import Config\n"})
        |> install(["--no-startup-guard"])
        |> assert_unchanged()
        |> refute_creates("config/host.exs")
        |> assert_has_notice(&(&1 =~ "Nerves.Runtime.KVBackend.InMemory"))
      end

      test "no notice when there is no config/host.exs but kv_backend is already configured" do
        igniter =
          test_project(
            files: %{
              "config/config.exs" => """
              import Config

              config :nerves_runtime, kv_backend: Nerves.Runtime.KVBackend.InMemory
              """
            }
          )
          |> install(["--no-startup-guard"])
          |> assert_unchanged()

        assert igniter.notices == []
      end
    end

    describe "startup guard" do
      test "is enabled in config/target.exs with a notice about rel/vm.args.eex" do
        nerves_project()
        |> install()
        |> assert_content_equals("config/target.exs", """
        import Config
        config :nerves_runtime, startup_guard_enabled: true
        """)
        |> assert_unchanged("config/config.exs")
        |> assert_has_notice(&(&1 =~ "HEART_INIT_TIMEOUT"))
      end

      test "is enabled by an explicit --startup-guard" do
        nerves_project()
        |> install(["--startup-guard"])
        |> assert_has_patch("config/target.exs", """
        + |config :nerves_runtime, startup_guard_enabled: true
        """)
      end

      test "no notice when rel/vm.args.eex already sets HEART_INIT_TIMEOUT" do
        igniter =
          nerves_project(%{"rel/vm.args.eex" => "-env HEART_INIT_TIMEOUT 600\n"})
          |> install()
          |> assert_has_patch("config/target.exs", """
          + |config :nerves_runtime, startup_guard_enabled: true
          """)
          |> assert_unchanged("rel/vm.args.eex")

        assert igniter.notices == []
      end

      test "is not enabled with --no-startup-guard" do
        igniter =
          nerves_project()
          |> install(["--no-startup-guard"])
          |> assert_unchanged("config/target.exs")

        assert igniter.notices == []
      end

      test "existing setting in config/target.exs is preserved" do
        igniter =
          nerves_project(%{
            "config/target.exs" => """
            import Config

            config :nerves_runtime, startup_guard_enabled: false
            """
          })
          |> install()
          |> assert_unchanged("config/target.exs")

        assert igniter.notices == []
      end

      test "existing setting in config/config.exs is preserved" do
        nerves_project(%{
          "config/config.exs" => """
          import Config

          config :nerves_runtime, startup_guard_enabled: false
          """
        })
        |> install()
        |> assert_unchanged(["config/target.exs", "config/config.exs"])
      end

      test "is not written and a notice is given when there is no config/target.exs" do
        test_project(files: %{"config/host.exs" => "import Config\n"})
        |> install()
        |> assert_unchanged("config/config.exs")
        |> refute_creates("config/target.exs")
        |> assert_has_notice(&(&1 =~ "so the startup guard was not"))
      end
    end

    describe "nerves application_sort" do
      test "is not created when the project doesn't have one" do
        nerves_project()
        |> install()
        |> assert_content_equals("config/target.exs", """
        import Config
        config :nerves_runtime, startup_guard_enabled: true
        """)
        |> assert_unchanged("config/config.exs")
      end

      test "nerves_runtime is added after logger_backends" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :nerves, application_sort: [init: [:logger_backends, :nerves_pack]]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/target.exs", """
        - |config :nerves, application_sort: [init: [:logger_backends, :nerves_pack]]
        + |config :nerves, application_sort: [init: [:logger_backends, :nerves_runtime, :nerves_pack]]
        """)
      end

      test "nerves_runtime is prepended when there is no logger_backends" do
        nerves_project(%{
          "config/config.exs" => """
          import Config

          config :nerves,
            application_sort: [
              init: [:nerves_pack],
              last: [:my_app]
            ]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/config.exs", """
        - |    init: [:nerves_pack],
        + |    init: [:nerves_runtime, :nerves_pack],
        """)
        |> assert_unchanged("config/target.exs")
      end

      test "nerves_runtime is added to an empty list" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :nerves, application_sort: [init: []]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/target.exs", """
        + |config :nerves, application_sort: [init: [:nerves_runtime]]
        """)
      end

      test "a list that already has nerves_runtime is preserved" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :nerves, application_sort: [init: [:nerves_pack, :nerves_runtime]]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_unchanged("config/target.exs")
      end

      test "a list that isn't a literal is left alone" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          init_apps = [:nerves_pack]
          config :nerves, application_sort: [init: init_apps]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_unchanged("config/target.exs")
      end

      test "other nerves config doesn't get an application_sort" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :nerves, :erlinit, update_clock: true
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_unchanged("config/target.exs")
      end
    end

    describe "shoehorn" do
      test "is left alone when the project doesn't use shoehorn" do
        igniter =
          nerves_project()
          |> install(["--no-startup-guard"])
          |> assert_unchanged("config/target.exs")

        assert igniter.notices == []
      end

      test "nerves_runtime is prepended to an existing init list in config/target.exs" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :shoehorn, init: [:foo]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/target.exs", """
        - |config :shoehorn, init: [:foo]
        + |config :shoehorn, init: [:nerves_runtime, :foo]
        """)
      end

      test "nerves_runtime is prepended to an existing init list in config/config.exs" do
        nerves_project(%{
          "config/config.exs" => """
          import Config

          config :shoehorn, init: [:foo]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/config.exs", """
        - |config :shoehorn, init: [:foo]
        + |config :shoehorn, init: [:nerves_runtime, :foo]
        """)
        |> assert_unchanged("config/target.exs")
      end

      test "an init list that already has nerves_runtime is preserved" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :shoehorn, init: [:nerves_pack, :nerves_runtime]
          """
        })
        |> install(["--no-startup-guard"])
        |> assert_unchanged("config/target.exs")
      end

      test "init is added to config/target.exs when shoehorn is a dependency" do
        nerves_project(%{"mix.exs" => @mix_exs_with_shoehorn})
        |> install(["--no-startup-guard"])
        |> assert_has_patch("config/target.exs", """
        + |config :shoehorn, init: [:nerves_runtime]
        """)
        |> assert_unchanged("config/config.exs")
      end

      test "init falls back to config/config.exs with a notice when there is no config/target.exs" do
        test_project(files: %{"mix.exs" => @mix_exs_with_shoehorn})
        |> install(["--no-startup-guard"])
        |> assert_creates("config/config.exs", """
        import Config
        config :shoehorn, init: [:nerves_runtime]
        """)
        |> refute_creates("config/target.exs")
        |> assert_has_notice(&(&1 =~ "so the shoehorn configuration"))
      end
    end

    describe "idempotency" do
      test "running twice on a Nerves 2 project changes nothing the second time" do
        nerves_project(%{
          "config/target.exs" => """
          import Config

          config :nerves, application_sort: [init: [:logger_backends]]
          """
        })
        |> install()
        |> apply_igniter!()
        |> install()
        |> assert_unchanged()
      end

      test "running twice on a Nerves project with shoehorn changes nothing the second time" do
        nerves_project(%{"mix.exs" => @mix_exs_with_shoehorn})
        |> install()
        |> apply_igniter!()
        |> install()
        |> assert_unchanged()
      end

      test "running twice on a plain project changes nothing the second time" do
        test_project(files: %{"mix.exs" => @mix_exs_with_shoehorn})
        |> install()
        |> apply_igniter!()
        |> install()
        |> assert_unchanged()
      end
    end
  end
end
