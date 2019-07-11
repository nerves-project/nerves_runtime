defmodule Nerves.Runtime.Log.KmsgTailer do
  @moduledoc """
  Collects operating system-level messages from `/proc/kmsg`,
  forwarding them to `Logger` with an appropriate level to match the syslog
  priority parsed out of the message.
  """

  use GenServer

  require Logger
  alias Nerves.Runtime.Log.Parser

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
    case Parser.parse_syslog(raw_entry) do
      %{facility: facility, severity: severity, message: message} ->
        _ =
          Logger.bare_log(
            logger_level(severity),
            message,
            module: __MODULE__,
            facility: facility,
            severity: severity
          )

      _ ->
        # This is unlikely to ever happen, but if a message was somehow
        # malformed and we couldn't parse the syslog priority, we should
        # still do a best-effort to pass along the raw data.
        _ = Logger.warn("Malformed kmsg report: #{inspect(raw_entry)}")
    end
  end

  defp logger_level(severity) when severity in [:emergency, :alert, :critical, :error], do: :error
  defp logger_level(severity) when severity == :warning, do: :warn
  defp logger_level(severity) when severity in [:notice, :informational], do: :info
  defp logger_level(severity) when severity == :debug, do: :debug
end
