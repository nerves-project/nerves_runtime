defmodule Nerves.Runtime.Log.Parser do
  @moduledoc """
  Functions for parsing syslog and kmsg strings
  """

  @doc """
  Parse out the syslog facility, severity, and message (including the timestamp
  and host) from a syslog-formatted string.

  The message is of the form:

  <pri>message

  `pri` is an integer that when broken apart gives you a facility and severity.
  `message` is everything else.
  """
  @spec parse_syslog(String.t()) ::
          %{facility: atom(), severity: atom(), message: binary()}
          | {:error, :not_syslog_format}
  def parse_syslog(<<"<", pri, ">", message::binary>>) when pri >= ?0 and pri <= ?9 do
    do_parse_syslog(<<pri>>, message)
  end

  def parse_syslog(<<"<", pri0, pri1, ">", message::binary>>)
      when pri0 >= ?1 and pri0 <= ?9 and pri1 >= ?0 and pri1 <= ?9 do
    do_parse_syslog(<<pri0, pri1>>, message)
  end

  def parse_syslog(<<"<", "1", pri0, pri1, ">", message::binary>>)
      when pri0 >= ?0 and pri0 <= ?9 and pri1 >= ?0 and pri1 <= ?9 do
    do_parse_syslog(<<"1", pri0, pri1>>, message)
  end

  def parse_syslog(_) do
    {:error, :not_syslog_format}
  end

  defp do_parse_syslog(pri, message) do
    {facility, severity} = decode_priority(pri)
    %{facility: facility, severity: severity, message: message}
  end

  defp decode_priority(str) do
    <<facility::size(5), severity::size(3)>> = <<String.to_integer(str)>>
    {facility_name(facility), severity_name(severity)}
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

  defp severity_name(0), do: :Emergency
  defp severity_name(1), do: :Alert
  defp severity_name(2), do: :Critical
  defp severity_name(3), do: :Error
  defp severity_name(4), do: :Warning
  defp severity_name(5), do: :Notice
  defp severity_name(6), do: :Informational
  defp severity_name(7), do: :Debug
end
