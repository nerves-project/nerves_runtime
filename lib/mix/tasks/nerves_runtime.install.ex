# SPDX-FileCopyrightText: 2025 Lars Wikman
# SPDX-FileCopyrightText: 2026 Lars Wikman
#
# SPDX-License-Identifier: Apache-2.0
#
defmodule Mix.Tasks.NervesRuntime.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Installs nerves_runtime in your Nerves project."
  end

  @spec example() :: String.t()
  def example() do
    "mix igniter.install nerves_runtime"
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    ## Example

    ```bash
    #{example()}
    ```

    ## What it does

    * Configures the in-memory `Nerves.Runtime.KV` backend in `config/host.exs`
      so that `Nerves.Runtime` functions work when running on the host for
      development and testing. Projects without a `config/host.exs` get a
      notice with the configuration to add instead, since it must not be
      applied on devices.
    * Enables `Nerves.Runtime.StartupGuard` in `config/target.exs`. It checks
      that all OTP applications start and then validates new firmware. Projects
      without a `config/target.exs` get a notice instead, since it must not be
      enabled on the host. Skip this with `--no-startup-guard`.
    * Makes sure that `:nerves_runtime` is started early on the device: if the
      project has a `config :nerves, application_sort: [init: [...]]` list
      (Nerves 2) or uses `shoehorn`, `:nerves_runtime` is added to that list.

    Existing configuration is never overwritten.

    ## Options

    * `--startup-guard` / `--no-startup-guard` - Enable
      `Nerves.Runtime.StartupGuard` on the device. Defaults to
      `--startup-guard`.
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.NervesRuntime.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    alias Igniter.Code.Common
    alias Igniter.Project.Config
    alias Igniter.Project.Deps
    alias Sourceror.Zipper

    # Keep this in sync with nerves_bootstrap's templates/new/config/host.exs
    @kv_backend """
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
    """

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        group: :nerves_runtime,
        example: __MODULE__.Docs.example(),
        schema: [startup_guard: :boolean],
        defaults: [startup_guard: true]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> configure_host_kv_backend()
      |> configure_startup_guard()
      |> configure_application_sort_init()
      |> configure_shoehorn_init()
    end

    # The in-memory KV backend is a host-only mock. It must never end up in
    # configuration that is evaluated for a device, so it is only written when
    # the project has a `config/host.exs`.
    defp configure_host_kv_backend(igniter) do
      cond do
        not Igniter.exists?(igniter, "config/host.exs") ->
          configure_host_kv_backend_without_host_exs(igniter)

        Config.configures_key?(igniter, "host.exs", :nerves_runtime, [:kv_backend]) ->
          igniter

        single_expression_with_trailing_comment?(igniter, "config/host.exs") ->
          append_host_kv_backend(igniter, "config/host.exs")

        true ->
          Config.configure_new(
            igniter,
            "host.exs",
            :nerves_runtime,
            [:kv_backend],
            {:code, Sourceror.parse_string!(@kv_backend)}
          )
      end
    end

    # Igniter 0.8 (via Sourceror) raises a FunctionClauseError when code is
    # added to a file that is a single expression followed only by comments,
    # like a `config/host.exs` with `import Config` and a comment below it.
    # Sourceror attaches such comments to a wrapper around the expression that
    # must not get a second child. Text is appended in that case instead.
    defp single_expression_with_trailing_comment?(igniter, path) do
      igniter = Igniter.include_existing_file(igniter, path)

      with {:ok, source} <- Rewrite.source(igniter.rewrite, path),
           {:ok, {:__block__, meta, [_single]}} <-
             Sourceror.parse_string(Rewrite.Source.get(source, :content)) do
        meta[:__sourceror__][:trailing_block] == true
      else
        _ -> false
      end
    end

    defp append_host_kv_backend(igniter, path) do
      value =
        @kv_backend
        |> String.trim_trailing()
        |> String.split("\n")
        |> Enum.map_join("\n", fn
          "" -> ""
          line -> "    " <> line
        end)

      Igniter.update_file(igniter, path, fn source ->
        content = source |> Rewrite.Source.get(:content) |> String.trim_trailing()

        Rewrite.Source.update(
          source,
          :content,
          content <> "\n\nconfig :nerves_runtime,\n  kv_backend:\n" <> value <> "\n"
        )
      end)
    end

    defp configure_host_kv_backend_without_host_exs(igniter) do
      if kv_backend_configured?(igniter) do
        igniter
      else
        Igniter.add_notice(igniter, """
        nerves_runtime: no config/host.exs found, so the host-side KV backend was
        not configured. This is expected for projects that were not generated as
        Nerves projects. To use Nerves.Runtime when running on the host (for
        development and tests), add the following to configuration that is only
        evaluated when Mix.target() == :host:

            config :nerves_runtime,
              kv_backend:
                {Nerves.Runtime.KVBackend.InMemory,
                 contents: %{
                   "nerves_fw_active" => "a",
                   "a.nerves_fw_architecture" => "generic",
                   "a.nerves_fw_description" => "N/A",
                   "a.nerves_fw_platform" => "host",
                   "a.nerves_fw_version" => "0.0.0"
                 }}
        """)
      end
    end

    defp kv_backend_configured?(igniter) do
      Enum.any?(["config.exs", "test.exs", "dev.exs"], fn file ->
        Igniter.exists?(igniter, Path.join("config", file)) and
          Config.configures_key?(igniter, file, :nerves_runtime, [:kv_backend])
      end)
    end

    # The startup guard registers a callback with `:heart` and validates the
    # running firmware. It's device-only and crashes without `:heart`, so it's
    # only written to `config/target.exs` and never to configuration that is
    # evaluated on the host.
    defp configure_startup_guard(igniter) do
      cond do
        not igniter.args.options[:startup_guard] ->
          igniter

        configured_in(igniter, :nerves_runtime, [:startup_guard_enabled]) ->
          igniter

        Igniter.exists?(igniter, "config/target.exs") ->
          igniter
          |> Config.configure_new("target.exs", :nerves_runtime, [:startup_guard_enabled], true)
          |> add_heart_init_timeout_notice()

        true ->
          Igniter.add_notice(igniter, """
          nerves_runtime: no config/target.exs found, so the startup guard was not
          enabled. This is expected for projects that were not generated as Nerves
          projects. To have new firmware validated once all OTP applications have
          started, add the following to configuration that is only evaluated on the
          device (when Mix.target() != :host):

              config :nerves_runtime, startup_guard_enabled: true

          See https://nerves-runtime.hexdocs.pm/Nerves.Runtime.StartupGuard.html
          """)
      end
    end

    defp add_heart_init_timeout_notice(igniter) do
      if heart_init_timeout_set?(igniter) do
        igniter
      else
        Igniter.add_notice(igniter, """
        nerves_runtime: enabled Nerves.Runtime.StartupGuard in config/target.exs.
        To also recover from the device hanging before the guard starts, add the
        following to your project's rel/vm.args.eex:

            ## Require an initialization handshake within 10 minutes
            -env HEART_INIT_TIMEOUT 600

        Delete `startup_guard_enabled` if you implement your own way of validating
        that firmware is good.
        """)
      end
    end

    defp heart_init_timeout_set?(igniter) do
      path = "rel/vm.args.eex"

      if Igniter.exists?(igniter, path) do
        igniter = Igniter.include_existing_file(igniter, path)

        case Rewrite.source(igniter.rewrite, path) do
          {:ok, source} -> Rewrite.Source.get(source, :content) =~ "HEART_INIT_TIMEOUT"
          _ -> false
        end
      else
        false
      end
    end

    # Nerves 2 sorts the applications in the release itself. The list belongs
    # to `:nerves`, so it's only updated when the project already has one.
    defp configure_application_sort_init(igniter) do
      path = [:application_sort, :init]

      case configured_in(igniter, :nerves, path) do
        nil ->
          igniter

        file ->
          Config.configure(igniter, file, :nerves, path, [:nerves_runtime],
            updater: &{:ok, add_to_init_list(&1)}
          )
      end
    end

    # shoehorn is optional (Nerves 2 projects don't use it). When it's in use,
    # nerves_runtime needs to be started by it before the other applications.
    defp configure_shoehorn_init(igniter) do
      existing = configured_in(igniter, :shoehorn, [:init])

      cond do
        existing ->
          add_to_shoehorn_init(igniter, existing)

        not Deps.has_dep?(igniter, :shoehorn) ->
          igniter

        Igniter.exists?(igniter, "config/target.exs") ->
          add_to_shoehorn_init(igniter, "target.exs")

        true ->
          igniter
          |> add_to_shoehorn_init("config.exs")
          |> Igniter.add_notice("""
          nerves_runtime: no config/target.exs found, so the shoehorn configuration
          was written to config/config.exs. It is intended for Nerves projects where
          it normally lives in config/target.exs.
          """)
      end
    end

    defp add_to_shoehorn_init(igniter, file) do
      Config.configure(igniter, file, :shoehorn, [:init], [:nerves_runtime],
        updater: &{:ok, add_to_init_list(&1)}
      )
    end

    # Returns the first of config/target.exs and config/config.exs that
    # configures the key or nil.
    defp configured_in(igniter, app, path) do
      Enum.find(["target.exs", "config.exs"], fn file ->
        Igniter.exists?(igniter, Path.join("config", file)) and
          Config.configures_key?(igniter, file, app, path)
      end)
    end

    # Adds `:nerves_runtime` to the front of a list of applications to start
    # first. `:logger_backends` stays ahead of it so that nerves_runtime's
    # startup is logged. Anything that isn't a literal list is left alone.
    defp add_to_init_list(zipper) do
      case Common.within(zipper, &add_to_literal_init_list/1) do
        {:ok, zipper} -> zipper
        :error -> zipper
      end
    end

    defp add_to_literal_init_list(list) do
      cond do
        not Igniter.Code.List.list?(list) ->
          :error

        Igniter.Code.List.find_list_item_index(list, &app?(&1, :nerves_runtime)) ->
          {:ok, list}

        true ->
          insert_in_init_list(list)
      end
    end

    defp insert_in_init_list(list) do
      case Igniter.Code.List.move_to_list_item(list, &app?(&1, :logger_backends)) do
        {:ok, item} -> {:ok, Zipper.insert_right(item, :nerves_runtime)}
        :error -> Igniter.Code.List.prepend_to_list(list, :nerves_runtime)
      end
    end

    defp app?(zipper, app), do: Common.nodes_equal?(zipper, app)
  end
else
  defmodule Mix.Tasks.NervesRuntime.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    @impl Mix.Task
    def run(_argv) do
      Mix.shell().error("""
      The task 'nerves_runtime.install' requires igniter. Please install igniter and try again.

      For more information, see: https://igniter.hexdocs.pm/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
