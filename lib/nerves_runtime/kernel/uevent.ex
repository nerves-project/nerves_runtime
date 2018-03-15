defmodule Nerves.Runtime.Kernel.UEvent do
  use GenServer
  require Logger
  alias Nerves.Runtime.Device

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    autoload = if opts[:autoload_modules] != nil, do: opts[:autoload_modules], else: true
    send(self(), :discover)
    executable = :code.priv_dir(:nerves_runtime) ++ '/uevent'

    port =
      Port.open({:spawn_executable, executable}, [
        {:args, []},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    {:ok, %{port: port, autoload: autoload, queue: :queue.new(), queue_len: 0}}
  end

  def handle_info(:discover, s) do
    Device.discover()
    {:noreply, s}
  end

  def handle_info({_, {:data, <<?n, message::binary>>}}, s) do
    msg = :erlang.binary_to_term(message)

    if s.queue_len == 0 do
      send(self(), :process_queue)
    end

    s = %{s | queue: :queue.in(msg, s.queue), queue_len: s.queue_len + 1}
    {:noreply, s}
  end

  def handle_info(:process_queue, s) do
    case :queue.out(s.queue) do
      {:empty, _queue} ->
        {:noreply, %{s | queue_len: 0}}

      {{:value, msg}, queue} ->
        handle_uevent(msg, s)
        send(self(), :process_queue)
        {:noreply, %{s | queue: queue, queue_len: s.queue_len - 1}}
    end
  end

  defp handle_uevent({:uevent, _uevent, kv}, s) do
    event =
      Enum.reduce(kv, %{}, fn str, acc ->
        [k, v] = String.split(str, "=", parts: 2)
        k = String.downcase(k)
        Map.put(acc, k, v)
      end)

    case Map.get(event, "devpath", "") do
      "/devices" <> _path -> registry(event, s)
      _ -> :noop
    end
  end

  def registry(%{"action" => "add", "devpath" => devpath} = event, s) do
    attributes = Map.drop(event, ["action", "devpath"])
    scope = scope(devpath)
    # Logger.debug "UEvent Add: #{inspect scope}"
    if subsystem = Map.get(event, "subsystem") do
      SystemRegistry.update_in(subsystem_scope(subsystem), fn v ->
        v = if is_nil(v), do: [], else: v
        [scope | v]
      end)
    end

    if s.autoload, do: modprobe(event)
    SystemRegistry.update(scope, attributes)
  end

  def registry(%{"action" => "remove", "devpath" => devpath} = event, _) do
    scope = scope(devpath)
    # Logger.debug "UEvent Remove: #{inspect scope}"
    SystemRegistry.delete(scope)

    if subsystem = Map.get(event, "subsystem") do
      SystemRegistry.update_in(subsystem_scope(subsystem), fn v ->
        v = if is_nil(v), do: [], else: v
        {_, scopes} = Enum.split_with(v, fn v -> v == scope end)
        scopes
      end)
    end
  end

  def registry(%{"action" => "change"} = event, s) do
    # Logger.debug "UEvent Change: #{inspect event}"
    raw = Map.drop(event, ["action"])

    Map.put(raw, "action", "remove")
    |> registry(s)

    Map.put(raw, "action", "add")
    |> registry(s)
  end

  def registry(%{"action" => "move", "devpath" => new, "devpath_old" => old}, _) do
    # Logger.debug "UEvent Move: #{inspect scope(old)} -> #{inspect scope(new)}"
    SystemRegistry.move(scope(old), scope(new))
  end

  def registry(event, _) do
    Logger.debug("UEvent Unhandled: #{inspect(event)}")
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
