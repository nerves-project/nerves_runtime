defmodule Nerves.Runtime.Device.Handler do
  use GenStage

  require Logger

  @callback handle_connect(device :: Device.t, state :: term) ::
    {:noreply, new_state :: term}

  @callback handle_discover(device :: Device.t, state :: term) ::
    {:connect, new_state :: term} |
    {:noreply, new_state :: term}

  @callback handle_disconnect(device :: Device.t, state :: term) ::
    {:noreply, new_state :: term}

  @callback handle_call(call :: term, GenServer.from, state :: term) ::
    {:noreply, new_state :: term} |
    {:reply, reply :: term, new_state :: term}

  @callback handle_cast(cast :: term, state :: term) ::
    {:noreply, new_state :: term}

  @callback terminate(reason, state :: term) ::
    term when reason: :normal | :shutdown | {:shutdown, term} | term

  defmacro __using__(opts) do
    {adapter, opts} =
      case opts[:adapter] do
        {adapter, opts} -> {adapter, opts}
        adapter -> {adapter, []}
      end

    quote location: :keep do
      @behaviour Nerves.Runtime.Device.Handler
      @behaviour Nerves.Runtime.Device.Adapter.Connection

      @adapter unquote(adapter)
      @adapter_opts unquote(opts)

      def __adapter__, do: {@adapter, @adapter_opts}

      def start_link() do
        Nerves.Runtime.Device.Handler.start_link(__MODULE__, [])
      end

      @doc false
      def handle_call(_, _, s) do
        {:noreply, s}
      end

      @doc false
      def handle_cast(_, s) do
        {:noreply, s}
      end

      @doc false
      def terminate(_reason, _state) do
        :ok
      end

      defoverridable [start_link: 0, handle_call: 3, handle_cast: 2]
    end
  end

  def start_link(mod, state, opts \\ []) do
    IO.puts "opts: #{inspect opts}"
    {:ok, pid} = GenStage.start_link(__MODULE__, {mod, state}, opts)
    GenStage.sync_subscribe(pid, to: Nerves.Runtime.Device.Tree)
    {:ok, pid}
  end

  def call(pid, call, timeout \\ 5000) do
    GenStage.call(pid, call, timeout)
  end

  def cast(pid, request) do
    GenStage.cast(pid, request)
  end

  def init({mod, state}) do

    Process.flag(:trap_exit, true)
    {adapter, opts} = mod.__adapter__()
    s = %{
      status: :disconnected,
      handler_state: state,
      mod: mod,
      adapter: {{adapter, opts}, nil},
      subsystem: adapter.__subsystem__(),
      device: nil
    }

    {:ok, devices} = Nerves.Runtime.Device.Tree.register_handler(mod)
    s =
      if devices != [] do
        Enum.reduce(devices, s, fn (device, acc) ->
          {:noreply, [], s} = handle_events([{s.subsystem, :add, device}], self(), acc)
          s
        end)
      else
        s
      end
    {:consumer, s}
  end

  # handler is ready to discover devices
  def handle_events([{subsystem, :add, device}], _from, %{subsystem: subsystem, status: :disconnected} = s) do
    s =
      case s.mod.handle_discover(device, s.handler_state) do
        {:noreply, handler_state} ->
          put_in(s, [:handler_state], handler_state)
        {:connect, device, handler_state} ->
          s = put_in(s, [:handler_state], handler_state)
          connect_device(device, s)
      end
    {:noreply, [], s}
  end

  # The connected device has disconnected
  def handle_events([{subsystem, :remove, device}], _from, %{subsystem: subsystem, status: :connected, device: device} = s) do
    s =
      case s.mod.handle_disconnect(device, s.handler_state) do
        {:noreply, handler_state} ->
          put_in(s, [:handler_state], handler_state)
      end
    {:noreply, [], s}
  end

  def handle_events(_events, _from, s) do
    {:noreply, [], s}
  end

  def handle_call(request, from, s) do
    case s.mod.handle_call(request, from, s.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, [], put_in(s, [:handler_state], handler_state)}
      {:reply, reply, handler_state} ->
        {:reply, reply, [], put_in(s, [:handler_state], handler_state)}
    end
  end

  def handle_cast(request, s) do
    case s.mod.handle_cast(request, s.handler_state) do
      {:noreply, handler_state} ->
        {:noreply, [], put_in(s, [:handler_state], handler_state)}
    end
  end

  def handle_info({:adapter, :data_in, data}, s) do
    s =
      case s.mod.handle_data_in(s.device, data, s.handler_state) do
        {:noreply, handler_state} ->
          put_in(s, [:handler_state], handler_state)
      end
    {:noreply, [], s}
  end

  def handle_info({:EXIT, pid, _reason}, %{adapter: {_mod, pid}, status: :connected} = s) do
    # The adaptor went down. Let the handler know if they haven't already been told
    s =
      case s.mod.handle_disconnect(s.device, s.handler_state) do
        {:noreply, handler_state} ->
          put_in(s, [:handler_state], handler_state)
      end
    {:noreply, [], disconnect_device(s.device, s)}
  end
  def handle_info({:EXIT, pid, _reason}, %{adapter: {_mod, pid}} = s) do
    {:noreply, [], disconnect_device(s.device, s)}
  end
  def handle_info({:EXIT, _from, :normal}, s) do
    {:noreply, [], s}
  end

  def connect_device(device, %{adapter: {{mod, opts}, nil}} = s) do
    {:ok, pid} = mod.start_link(opts)
    :ok = mod.connect(pid, device)
    s =
      case s.mod.handle_connect(device, s.handler_state) do
        {:noreply, handler_state} ->
          put_in(s, [:handler_state], handler_state)
      end
    %{s | status: :connected, device: device, adapter: {{mod, opts}, pid}}
  end

  def disconnect_device(_device, %{adapter: {{mod, opts}, pid}} = s) do
    if Process.alive?(pid), do: mod.stop(pid)
    %{s | status: :disconnected, device: nil, adapter: {{mod, opts}, nil}}
  end
end
