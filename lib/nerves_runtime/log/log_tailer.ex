defmodule Nerves.Runtime.Log.LogTailer do
  @moduledoc """
  Collects operating system-level messages from `/proc/kmsg`,
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
  alias Nerves.Runtime.Log.Parser

  defp gen_server_name(:kmsg), do: __MODULE__.Kmsg

  @doc """
  `type` must be `:kmsg` to indicate which log to tail with this
  process. They're managed by separate processes, both to isolate failures and
  to simplify the handling of messages being sent back from the ports.
  """
  @spec start_link(:kmsg) :: {:ok, pid()}
  def start_link(type) do
    enabled = Application.get_env(:nerves_runtime, :enable_syslog, true)
    GenServer.start_link(__MODULE__, %{type: type, enabled: enabled}, name: gen_server_name(type))
  end

  @spec init(%{type: :kmsg, enabled: boolean()}) ::
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
    :code.priv_dir(:nerves_runtime) ++ '/log_tailer'
  end

  defp handle_message(type, data) do
    case Parser.parse_syslog(data) do
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

  defp logger_level(severity) when severity in [:Emergency, :Alert, :Critical, :Error], do: :error
  defp logger_level(severity) when severity == :Warning, do: :warn
  defp logger_level(severity) when severity in [:Notice, :Informational], do: :info
  defp logger_level(severity) when severity == :Debug, do: :debug
end
