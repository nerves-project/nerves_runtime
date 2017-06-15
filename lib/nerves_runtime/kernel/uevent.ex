defmodule Nerves.Runtime.Kernel.UEvent do
  use GenServer
  require Logger
  alias Nerves.Runtime.Device

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Logger.debug "Start UEvent Mon"
    send(self(), :discover)
    executable = :code.priv_dir(:nerves_runtime) ++ '/uevent'
    port = Port.open({:spawn_executable, executable},
    [{:args, []},
      {:packet, 2},
      :use_stdio,
      :binary,
      :exit_status])

    {:ok, %{port: port}}
  end

  def handle_info(:discover, state) do
    Device.discover
    {:noreply, state}
  end

  def handle_info({_, {:data, <<?n, message::binary>>}}, state) do
    msg = :erlang.binary_to_term(message)
    handle_port(msg, state)
  end

  defp handle_port({:uevent, _uevent, kv}, state) do
    event =
      Enum.reduce(kv, %{}, fn (str, acc) ->
        [k, v] = String.split(str, "=")
        k = String.downcase(k)
        Map.put(acc, k, v)
      end)
    case Map.get(event, "devpath", "") do
      "/devices" <> _path -> registry(event)
      _ -> :noop
    end
    {:noreply, state}
  end

  def registry(%{"action" => "add", "devpath" => devpath} = event) do
    scope = scope(devpath)
    #Logger.debug "UEvent Add: #{inspect scope}"
    attributes = Map.drop(event, ["action", "devpath"])
    SystemRegistry.update(scope(devpath), attributes)
  end

  def registry(%{"action" => "remove", "devpath" => devpath}) do
    scope = scope(devpath)
    #Logger.debug "UEvent Remove: #{inspect scope}"
    SystemRegistry.delete(scope)
  end

  def registry(%{"action" => "change"} = event) do
    #Logger.debug "UEvent Change: #{inspect event}"
    raw = Map.drop(event, ["action"])
    Map.put(raw, "action", "remove")
    |> registry

    Map.put(raw, "action", "add")
    |> registry
  end

  def registry(%{"action" => "move", "devpath" => new, "devpath_old" => old}) do
    #Logger.debug "UEvent Move: #{inspect scope(old)} -> #{inspect scope(new)}"
    SystemRegistry.move(scope(old), scope(new))
  end

  def registry(event) do
    Logger.debug "UEvent Unhandled: #{inspect event}"
  end

  defp scope("/" <> devpath) do
    scope(devpath)
  end
  defp scope(devpath) do
    [:state | String.split(devpath, "/")]
  end

end
