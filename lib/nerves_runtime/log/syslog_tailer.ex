defmodule Nerves.Runtime.Log.SyslogTailer do
  use GenServer
  require Logger

  @moduledoc """
  This GenServer routes syslog messages from C-based applications and libraries through
  the Elixir Logger for collection.
  """

  alias Nerves.Runtime.Log.SyslogParser

  @syslog_path "/dev/log"

  @doc """
  Start the local syslog GenServer.
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    # Blindly try to remove an old file just in case it exists from a previous run
    _ = File.rm(@syslog_path)

    {:ok, log_port} =
      :gen_udp.open(0, [:local, :binary, {:active, true}, {:ip, {:local, @syslog_path}}])

    # All processes should be able to log messages
    File.chmod!(@syslog_path, 0o666)

    {:ok, log_port}
  end

  @impl true
  def handle_info({:udp, log_port, _, 0, raw_entry}, log_port) do
    case SyslogParser.parse(raw_entry) do
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

        :ok

      _ ->
        # This is unlikely to ever happen, but if a message was somehow
        # malformed and we couldn't parse the syslog priority, we should
        # still do a best-effort to pass along the raw data.
        _ = Logger.warn("Malformed syslog report: #{inspect(raw_entry)}")
        :ok
    end

    {:noreply, log_port}
  end
end
