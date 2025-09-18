defmodule Mix.Tasks.NervesRuntime.Install.Docs do
  @moduledoc false

  @spec short_doc() :: String.t()
  def short_doc() do
    "Install the Nerves Runtime tools."
  end

  @spec example() :: String.t()
  def example() do
    """
    mix nerves_runtime.install
    """
  end

  @spec long_doc() :: String.t()
  def long_doc() do
    """
    #{short_doc()}

    ## Examples

    ```bash
    #{example()}
    ```
    """
  end
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.NervesRuntime.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"

    @moduledoc __MODULE__.Docs.long_doc()

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _composing_task) do
      %Igniter.Mix.Task.Info{
        # Groups allow for overlapping arguments for tasks by the same author
        # See the generators guide for more.
        group: :nerves_runtime,
        # *other* dependencies to add
        # i.e `{:foo, "~> 2.0"}`
        adds_deps: [],
        # *other* dependencies to add and call their associated installers, if they exist
        # i.e `{:foo, "~> 2.0"}`
        installs: [],
        # An example invocation
        example: __MODULE__.Docs.example(),
        # A list of environments that this should be installed in.
        only: nil,
        # a list of positional arguments, i.e `[:file]`
        positional: [],
        # Other tasks your task composes using `Igniter.compose_task`, passing in the CLI argv
        # This ensures your option schema includes options from nested tasks
        composes: [],
        # `OptionParser` schema
        schema: [],
        # Default values for the options in the `schema`
        defaults: [],
        # CLI aliases
        aliases: [],
        # A list of options in the schema that are required
        required: []
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      kv_backend_config =
        {Nerves.Runtime.KVBackend.InMemory,
         contents: %{
           # The KV store on Nerves systems is typically read from UBoot-env, but
           # this allows us to use a pre-populated InMemory store when running on
           # host for development and testing.
           #
           # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
           # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata

           "nerves_fw_active" => "a",
           "a.nerves_fw_architecture" => "generic",
           "a.nerves_fw_description" => "N/A",
           "a.nerves_fw_platform" => "host",
           "a.nerves_fw_version" => "0.0.0"
         }}

      igniter
      |> Igniter.Project.Config.configure("target.exs", :shoehorn, [:init], [:nerves_runtime],
        updater: &Igniter.Code.List.prepend_new_to_list(&1, :nerves_runtime)
      )
      |> Igniter.Project.Config.configure(
        "host.exs",
        :nerves_runtime,
        [:kv_backend],
        {:code, kv_backend_config}
      )
    end
  end
else
  defmodule Mix.Tasks.NervesRuntime.Install do
    @shortdoc "#{__MODULE__.Docs.short_doc()} | Install `igniter` to use"

    @moduledoc __MODULE__.Docs.long_doc()

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'nerves_runtime.install' requires igniter. Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter/readme.html#installation
      """)

      exit({:shutdown, 1})
    end
  end
end
