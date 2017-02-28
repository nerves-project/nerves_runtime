defmodule Nerves.Runtime.Kernel.UEvent do
  @moduledoc ~S"""
  Provides a GenStage.BroadcastDispatcher which produces messages
  received by the Linux UEvemt Interface.

  These messages represent hotplug events for devices. Events will be
  delivered in the following 3 tuple format

    {:uevent, event_string :: String.t, key_values :: map}

  For Example:

    {:uevent, "add@/devices/pci0000:00/0000:00:1d.0/usb2/2-1/2-1:1.0/tty/ttyACM0",
      %{action: "add", devname: "ttyACM0",
        devpath: "/devices/pci0000:00/0000:00:1d.0/usb2/2-1/2-1:1.0/tty/ttyACM0",
        major: "166", minor: "0", seqnum: "2946", subsystem: "tty"}}

  To consume the UEvent GenStage, create a consumer and sync_subscribe

    defmodule Consumer do
      use GenStage

      @doc "Starts the consumer."
      def start_link() do
        GenStage.start_link(__MODULE__, :ok)
      end

      def init(:ok) do
        # Starts a permanent subscription to the broadcaster
        # which will automatically start requesting items.
        {:consumer, :ok, subscribe_to: [Nerves.Runtime.Kernel.UEvent]}
      end

      def handle_events(events, _from, state) do
        for event <- events do
          IO.inspect {self(), event}
        end
        {:noreply, [], state}
      end
    end


  """
  use GenStage

  @doc """
  Starts a UEvent Stage linked to the current process
  """
  @spec start_link() :: GenStage.on_start
  def start_link() do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    executable = :code.priv_dir(:nerves_runtime) ++ '/uevent'
    port = Port.open({:spawn_executable, executable},
    [{:args, []},
      {:packet, 2},
      :use_stdio,
      :binary,
      :exit_status])

    {:producer, %{port: port}, dispatcher: GenStage.BroadcastDispatcher}
  end

  def handle_call({:notify, event}, _from, state) do
    {:reply, :ok, [event], state} # Dispatch immediately
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state} # We don't care about the demand
  end

  def handle_info({_, {:data, <<?n, message::binary>>}}, state) do
    msg = :erlang.binary_to_term(message)
    handle_port(msg, state)
  end

  defp handle_port({:uevent, uevent, kv}, state) do
    kv = kv
      |> Enum.reduce(%{}, fn (str, acc) ->
        [k, v] = String.split(str, "=")
        k = String.downcase(k)
        Map.put(acc, String.to_atom(k), v)
      end)
    event = {:uevent, to_string(uevent), kv}
    |> IO.inspect
    {:noreply, [event], state}
  end
end
