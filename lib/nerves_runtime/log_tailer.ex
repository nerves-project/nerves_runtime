defmodule Nerves.Runtime.LogTailer do
  @moduledoc """
  Collects operating system-level messages from `/dev/log` and `/proc/kmsg`,
  forwarding them to `Logger` with an appropriate level to match the syslog
  priority parsed out of the message.

  You can disable this feature (e.g. for testing) by configuring the following
  option:

  ```elixir
  # config.exs
  config :nerves_runtime, enable_syslog: false
  ```
  """

  use GenServer

  require Logger

  @port_binary_name "log_tailer"

  defp gen_server_name(:syslog), do: __MODULE__.Syslog
  defp gen_server_name(:kmsg), do: __MODULE__.Kmsg

  @type type :: :syslog | :kmsg

  @doc """
  `type` must be `:syslog` or `:kmsg` to indicate which log to tail with this
  process. They're managed by separate processes, both to isolate failures and
  to simplify the handling of messages being sent back from the ports.
  """
  @spec start_link(:syslog | :kmsg) :: {:ok, pid()}
  def start_link(type) do
    enabled = Application.get_env(:nerves_runtime, :enable_syslog, true)
    GenServer.start_link(__MODULE__, %{type: type, enabled: enabled}, name: gen_server_name(type))
  end

  @spec init(%{type: :syslog | :kmsg, enabled: boolean()}) ::
          {:ok, %{type: atom(), port: port(), buffer: binary()}} | :ignore
  def init(%{enabled: false}), do: :ignore
  def init(%{type: type}), do: {:ok, %{type: type, port: open_port(type), buffer: ""}}

  def handle_info({port, {:data, {:noeol, fragment}}}, %{port: port, buffer: buffer} = state) do
    {:noreply, %{state | buffer: buffer <> fragment}}
  end

  def handle_info(
        {port, {:data, {:eol, fragment}}},
        %{type: type, port: port, buffer: buffer} = state
      ) do
    handle_message(type, buffer <> fragment)
    {:noreply, %{state | buffer: ""}}
  end

  defp open_port(type) do
    Port.open({:spawn_executable, executable()}, [
      {:args, [to_string(type)]},
      {:line, 1024},
      :use_stdio,
      :binary,
      :exit_status
    ])
  end

  defp executable() do
    :nerves_runtime
    |> :code.priv_dir()
    |> Path.join(@port_binary_name)
  end

  defp handle_message(type, data) do
    case parse_syslog_message(data) do
      %{facility: facility, severity: severity, message: message} ->
        Logger.bare_log(
          logger_level(severity),
          message,
          module: gen_server_name(type),
          facility: facility,
          severity: severity
        )

      _ ->
        # This is unlikely to ever happen, but if a message was somehow
        # malformed and we couldn't parse the syslog priority, we should
        # still do a best-effort to pass along the raw data.
        Logger.bare_log(:info, data, module: gen_server_name(type))
    end
  end

  @doc """
  Parse out the syslog facility, severity, and message (including the timestamp
  and host) from a syslog-formatted string.
  """
  @spec parse_syslog_message(binary()) ::
          %{facility: atom(), severity: atom(), message: binary()}
          | {:error, :not_syslog_format}
  def parse_syslog_message(data) do
    case Regex.named_captures(~r/^<(?<pri>\d{1,3})>(?<message>.*)$/, data) do
      %{"pri" => pri, "message" => message} ->
        {facility, severity} = pri |> String.to_integer() |> divmod(8)
        %{facility: facility_name(facility), severity: severity_name(severity), message: message}

      _ ->
        {:error, :not_syslog_format}
    end
  end

  defp divmod(numerator, denominator),
    do: {div(numerator, denominator), Integer.mod(numerator, denominator)}

  defp facility_name(0), do: :kernel
  defp facility_name(1), do: :user_level
  defp facility_name(2), do: :mail
  defp facility_name(3), do: :system
  defp facility_name(4), do: :security_authorization
  defp facility_name(5), do: :syslogd
  defp facility_name(6), do: :line_printer
  defp facility_name(7), do: :network_news
  defp facility_name(8), do: :UUCP
  defp facility_name(9), do: :clock
  defp facility_name(10), do: :security_authorization
  defp facility_name(11), do: :FTP
  defp facility_name(12), do: :NTP
  defp facility_name(13), do: :log_audit
  defp facility_name(14), do: :log_alert
  defp facility_name(15), do: :clock
  defp facility_name(16), do: :local0
  defp facility_name(17), do: :local1
  defp facility_name(18), do: :local2
  defp facility_name(19), do: :local3
  defp facility_name(20), do: :local4
  defp facility_name(21), do: :local5
  defp facility_name(22), do: :local6
  defp facility_name(23), do: :local7

  defp severity_name(0), do: :Emergency
  defp severity_name(1), do: :Alert
  defp severity_name(2), do: :Critical
  defp severity_name(3), do: :Error
  defp severity_name(4), do: :Warning
  defp severity_name(5), do: :Notice
  defp severity_name(6), do: :Informational
  defp severity_name(7), do: :Debug

  defp logger_level(severity) when severity in [:Emergency, :Alert, :Critical, :Error], do: :error
  defp logger_level(severity) when severity == :Warning, do: :warn
  defp logger_level(severity) when severity in [:Notice, :Informational], do: :info
  defp logger_level(severity) when severity == :Debug, do: :debug
end
