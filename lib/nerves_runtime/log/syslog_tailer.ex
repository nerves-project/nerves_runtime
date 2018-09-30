defmodule Nerves.Runtime.Log.SyslogTailer do
  use GenServer
  require Logger

  @moduledoc """
  This GenServer routes syslog messages from C-based applications and libraries through
  the Elixir Logger for collection.
  """

  alias Nerves.Runtime.Log.Parser

  @syslog_path "/dev/log"

  @doc """
  Start the local syslog GenServer.
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    # Blindly try to remove an old file just in case it exists from a previous run
    File.rm(@syslog_path)

    {:ok, log_port} =
      :gen_udp.open(0, [:local, :binary, {:active, true}, {:ip, {:local, @syslog_path}}])

    # All processes should be able to log messages
    File.chmod!(@syslog_path, 0o666)

    {:ok, log_port}
  end

  def handle_info({:udp, log_port, _, 0, raw_entry}, log_port) do
    case Parser.parse_syslog(raw_entry) do
      %{facility: facility, severity: severity, message: message} ->
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
        Logger.warn("Malformed syslog report: #{inspect(raw_entry)}")
    end

    {:noreply, log_port}
  end

  defp logger_level(severity) when severity in [:Emergency, :Alert, :Critical, :Error], do: :error
  defp logger_level(severity) when severity == :Warning, do: :warn
  defp logger_level(severity) when severity in [:Notice, :Informational], do: :info
  defp logger_level(severity) when severity == :Debug, do: :debug
end
