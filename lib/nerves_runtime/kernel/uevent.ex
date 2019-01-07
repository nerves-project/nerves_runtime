defmodule Nerves.Runtime.Kernel.UEvent do
  use GenServer
  require Logger
  alias Nerves.Runtime.Device

  @moduledoc """
  GenServer that captures Linux uevent messages and passes them up to Elixir.
  """

  defmodule State do
    @moduledoc false

    defstruct [:port, :discover_ref, :autoload]
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    autoload = Keyword.get(opts, :autoload_modules, true)
    executable = :code.priv_dir(:nerves_runtime) ++ '/uevent'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    # Trigger uevent messages to be sent for all devices that have been enumerated
    # by the Linux kernel before this GenServer started.
    discover_task = Task.async(&Device.discover/0)

    {:ok, %State{port: port, discover_ref: discover_task.ref, autoload: autoload}}
  end

  @impl true
  def handle_info({port, {:data, message}}, %State{port: port} = s) do
    {action, devpath, kvmap} = :erlang.binary_to_term(message)
    registry(action, devpath, kvmap, s)
    {:noreply, s}
  end

  @impl true
  def handle_info({ref, result}, %State{discover_ref: ref} = s) do
    Logger.debug("UEvent initial device discovery completed: #{result}")
    {:noreply, s}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, :normal}, %State{discover_ref: ref} = s) do
    # Ignore the discovery task's process ending
    {:noreply, s}
  end

  def registry("add", devpath, kvmap, s) do
    scope = scope(devpath)
    # Logger.debug "uevent add: #{inspect scope}"
    if subsystem = Map.get(kvmap, "subsystem") do
      SystemRegistry.update_in(subsystem_scope(subsystem), fn v ->
        v = if is_nil(v), do: [], else: v
        [scope | v]
      end)
    end

    if s.autoload, do: modprobe(kvmap)
    SystemRegistry.update(scope, kvmap)
  end

  def registry("remove", devpath, kvmap, _s) do
    scope = scope(devpath)
    # Logger.debug "uevent remove: #{inspect scope}"
    SystemRegistry.delete(scope)

    if subsystem = Map.get(kvmap, "subsystem") do
      SystemRegistry.update_in(subsystem_scope(subsystem), fn v ->
        v = if is_nil(v), do: [], else: v
        {_, scopes} = Enum.split_with(v, fn v -> v == scope end)
        scopes
      end)
    end
  end

  def registry("move", new, %{"devpath_old" => old}, _s) do
    # Logger.debug "uevent move: #{inspect scope(old)} -> #{inspect scope(new)}"
    SystemRegistry.move(scope(old), scope(new))
  end

  def registry(_action, _devpath, _kvmap, _s) do
    # Logger.debug("uevent unhandled: #{inspect(action)}")
  end

  defp scope("/" <> devpath) do
    scope(devpath)
  end

  defp scope(devpath) do
    [:state | String.split(devpath, "/")]
  end

  defp subsystem_scope(subsystem) do
    [:state, "subsystems", subsystem]
  end

  defp modprobe(%{"modalias" => modalias}) do
    System.cmd("modprobe", [modalias], stderr_to_stdout: true)
  end

  defp modprobe(_), do: :noop
end
