defmodule Nerves.Runtime.Device.Tree do
  use GenStage

  require Logger

  @sysfs "/sys"

  def start_link() do
    {:ok, pid} = GenStage.start_link(__MODULE__, [], name: __MODULE__)
    GenStage.sync_subscribe(pid, to: Nerves.Runtime.Kernel.UEvent)
    {:ok, pid}
  end

  def register_handler(mod, pid \\ nil) do
    pid = pid || self()
    GenStage.call(__MODULE__, {:register_handler, mod, pid})
  end

  # GenStage API

  def init([]) do
    {:producer_consumer, %{
      handlers: [],
      devices: discover_devices(),
    }, dispatcher: GenStage.BroadcastDispatcher, buffer_size: 0}
  end

  def handle_events([{:uevent, _, %{action: "add"} = data}], _from, s) do
    device =
      Path.join(@sysfs, data.devpath)
      |> load_device(data.subsystem)
    devices = s.devices
    subsystem = String.to_atom(data.subsystem)
    subsystem_devices = Keyword.get(devices, subsystem, [])
    devices = Keyword.put(s.devices, subsystem, [device | subsystem_devices])

    {:noreply, [{subsystem, :add, device}], %{s | devices: devices}}
  end

  def handle_events([{:uevent, _, %{action: "remove"} = data}], _from, s) do
    subsystem = String.to_atom(data.subsystem)
    subsystem_devices =
      s.devices
      |> Keyword.get(subsystem, [])
      |> Enum.filter(& &1.subsystem == subsystem)
    event_devpath = Path.join(@sysfs, data.devpath)
    device = Enum.find(subsystem_devices, & &1.devpath == event_devpath)

    subsystem_devices =
      case device do
        %Nerves.Runtime.Device{devpath: devpath} ->
          Enum.reject(subsystem_devices, & &1.devpath == devpath)
        _ -> subsystem_devices
      end
    devices = Keyword.put(s.devices, subsystem, subsystem_devices)
    {:noreply, [{subsystem, :remove, device}], %{s | devices: devices}}
  end

  def handle_events(_events, _from, s) do
    {:noreply, [], s}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state} # We don't care about the demand
  end

  # Server API

  def handle_call({:register_handler, mod, pid}, _from, s) do
    {adapter, _opts} = mod.__adapter__()
    subsystem = adapter.__subsystem__
    devices = Keyword.get(s.devices, subsystem, [])
    s = %{s | handlers: [{mod, pid} | s.handlers]}
    {:reply, {:ok, devices}, [], s}
  end

  # Private Functions

  defp discover_devices do
    class_dir = "/sys/class"
    File.ls!(class_dir)
    # walk the classes and find all options, then group
    |> Enum.reduce([], fn(subsystem, acc) ->
      subsystem_path = Path.join(class_dir, subsystem)
      # first create device pids
      devices = subsystem_devices(subsystem, subsystem_path)
      Keyword.put(acc, String.to_atom(subsystem), devices)
    end)
  end

  defp subsystem_devices(subsystem, path) do
    path
    |> File.ls!()
    |> Enum.map(& Path.join(path, &1))
    |> Enum.reject(& File.lstat!(&1).type != :symlink)
    |> Enum.map(& expand_symlink(&1, path))
    |> Enum.map(& load_device(&1, subsystem))
  end

  defp load_device(devpath, subsystem) do
    Nerves.Runtime.Device.load(devpath, subsystem)
  end

  defp expand_symlink(path, dir) do
    {:ok, link} = :file.read_link(String.to_char_list(path))
    link
    |> to_string
    |> Path.expand(dir)
  end

end
