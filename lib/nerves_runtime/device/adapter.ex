defmodule Nerves.Runtime.Device.Adapter do
  alias Nerves.Runtime.Device

  @callback attributes(Device.t) :: map

  defmacro __using__(opts) do
    quote do
      use GenServer
      @behaviour Nerves.Runtime.Device.Adapter
      @subsystem unquote(opts[:subsystem])

      def __subsystem__, do: @subsystem

      def attributes(_dev), do: %{}

      def start_link(adapter_opts \\ []) do
        Nerves.Runtime.Device.Adapter.start_link(__MODULE__, self(), adapter_opts)
      end

      def stop(pid) do
        GenServer.stop(pid)
      end

      def connect(pid, device) do
        GenServer.call(pid, {:connect, device})
      end

      defoverridable [attributes: 1]
    end
  end

  def start_link(mod, handler, adapter_opts) do
    GenServer.start_link(__MODULE__, {mod, handler, adapter_opts})
  end

  def init({mod, handler, adapter_opts}) do
    {:ok, %{
      handler: handler,
      adapter_state: %{opts: adapter_opts},
      mod: mod
    }}
  end

  def handle_call({:connect, device}, _from, s) do
    case s.mod.handle_connect(device, s.adapter_state) do
      {:ok, adapter_state} ->
        put_in(s, [:adapter_state], adapter_state)
        {:reply, :ok, s}
      {:error, error, s} ->
        {:reply, {:error, error}, s}
    end
  end

  def handle_info(data, s) do
    s =
      case s.mod.handle_info(data, s.adapter_state) do
        {:data_in, data, adapter_state} ->
          send(s.handler, {:adapter, :data_in, data})
          put_in(s, [:adapter_state], adapter_state)
      end
    {:noreply, s}
  end

end
