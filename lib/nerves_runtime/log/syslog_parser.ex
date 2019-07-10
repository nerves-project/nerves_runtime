defmodule Nerves.Runtime.Log.SyslogParser do
  @moduledoc """
  Functions for parsing syslog strings
  """

  @type severity ::
          :alert | :critical | :debug | :emergency | :error | :informational | :notice | :warning

  @type facility ::
          :kernel
          | :user_level
          | :mail
          | :system
          | :security_authorization
          | :syslogd
          | :line_printer
          | :network_news
          | :UUCP
          | :clock
          | :security_authorization
          | :FTP
          | :NTP
          | :log_audit
          | :log_alert
          | :clock
          | :local0
          | :local1
          | :local2
          | :local3
          | :local4
          | :local5
          | :local6
          | :local7

  @doc """
  Parse out the syslog facility, severity, and message (including the timestamp
  and host) from a syslog-formatted string.

  The message is of the form:

  ```text
  <pri>message
  ```

  `pri` is an integer that when broken apart gives you a facility and severity.
  `message` is everything else.
  """
  @spec parse(String.t()) ::
          {:ok, %{facility: facility(), severity: severity(), message: binary()}}
          | {:error, :parse_error}
  def parse(<<"<", pri, ">", message::binary>>) when pri >= ?0 and pri <= ?9 do
    do_parse(pri - ?0, message)
  end

  def parse(<<"<", pri0, pri1, ">", message::binary>>)
      when pri0 >= ?1 and pri0 <= ?9 and pri1 >= ?0 and pri1 <= ?9 do
    do_parse((pri0 - ?0) * 10 + (pri1 - ?0), message)
  end

  def parse(<<"<", ?1, pri0, pri1, ">", message::binary>>)
      when pri0 >= ?0 and pri0 <= ?9 and pri1 >= ?0 and pri1 <= ?9 do
    do_parse(100 + (pri0 - ?0) * 10 + (pri1 - ?0), message)
  end

  def parse(_) do
    {:error, :parse_error}
  end

  defp do_parse(pri, message) do
    with {:ok, facility, severity} <- decode_priority(pri) do
      {:ok, %{facility: facility, severity: severity, message: message}}
    end
  end

  @doc """
  Decode a syslog priority to facility and severity
  """
  @spec decode_priority(0..191) :: {:ok, facility(), severity()} | {:error, :parse_error}
  def decode_priority(priority) when priority >= 0 and priority <= 191 do
    facility = div(priority, 8)
    severity = Integer.mod(priority, 8)
    {:ok, facility_name(facility), severity_name(severity)}
  end

  def decode_priority(_priority) do
    {:error, :parse_error}
  end

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

  defp severity_name(0), do: :emergency
  defp severity_name(1), do: :alert
  defp severity_name(2), do: :critical
  defp severity_name(3), do: :error
  defp severity_name(4), do: :warning
  defp severity_name(5), do: :notice
  defp severity_name(6), do: :informational
  defp severity_name(7), do: :debug

  @doc """
  Convert severity to an Elixir logger level
  """
  @spec severity_to_logger(severity()) :: Logger.level()
  def severity_to_logger(severity) when severity in [:emergency, :alert, :critical, :error],
    do: :error

  def severity_to_logger(severity) when severity == :warning, do: :warn
  def severity_to_logger(severity) when severity in [:notice, :informational], do: :info
  def severity_to_logger(severity) when severity == :debug, do: :debug
end
