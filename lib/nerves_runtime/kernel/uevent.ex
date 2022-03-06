defmodule Nerves.Runtime.Kernel.UEvent do
  use GenServer
  require Logger

  @moduledoc """
  GenServer that captures Linux uevent messages and passes them up to Elixir.
  """

  @type state() :: %{port: port()}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    autoload = Keyword.get(opts, :autoload_modules, true)
    executable = :code.priv_dir(:nerves_runtime) ++ '/nerves_runtime'

    args = if autoload, do: ["modprobe"], else: []

    port =
      Port.open({:spawn_executable, executable}, [
        {:arg0, "uevent"},
        {:args, args},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    {:ok, %{port: port}}
  end

  @impl GenServer
  def handle_info({port, {:data, message}}, %{port: port} = s) do
    # {action, scope, kvmap} = :erlang.binary_to_term(message)
    # Logger.debug("uevent: #{inspect action}, #{inspect scope}, #{inspect kvmap}")
    {:noreply, s}
  end
end
