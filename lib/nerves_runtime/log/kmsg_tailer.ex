defmodule Nerves.Runtime.Log.KmsgTailer do
  @moduledoc """
  Collects operating system-level messages from `/proc/kmsg`,
  forwarding them to `Logger` with an appropriate level to match the syslog
  priority parsed out of the message.
  """

  use GenServer

  require Logger
  alias Nerves.Runtime.Log.{KmsgParser, SyslogParser}

  @doc """
  Start the kmsg monitoring GenServer.
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args), do: {:ok, %{port: open_port(), buffer: ""}}

  @impl true
  def handle_info({port, {:data, {:noeol, fragment}}}, %{port: port, buffer: buffer} = state) do
    {:noreply, %{state | buffer: buffer <> fragment}}
  end

  @impl true
  def handle_info(
        {port, {:data, {:eol, fragment}}},
        %{port: port, buffer: buffer} = state
      ) do
    _ = handle_message(buffer <> fragment)
    {:noreply, %{state | buffer: ""}}
  end

  defp open_port() do
    Port.open({:spawn_executable, executable()}, [
      {:arg0, "kmsg_tailer"},
      {:line, 1024},
      :use_stdio,
      :binary,
      :exit_status
    ])
  end

  defp executable() do
    :code.priv_dir(:nerves_runtime) ++ '/nerves_runtime'
  end

  defp handle_message(raw_entry) do
    case KmsgParser.parse(raw_entry) do
      {:ok, %{facility: facility, severity: severity, message: message}} ->
        level = SyslogParser.severity_to_logger(severity)

        _ =
          Logger.bare_log(
            level,
            message,
            module: __MODULE__,
            facility: facility,
            severity: severity
          )

      _ ->
        # We don't handle continuations and multi-line kmsg logs.

        # It's painful to ignore log messages, but these don't seem
        # to be reported by dmesg and the ones I've seen so far contain
        # redundant information that's primary value is that it's
        # machine parsable (i.e. key=value listings)
        :ok
    end
  end
end
