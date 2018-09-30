defmodule Nerves.Runtime.Log.Parser do
  @moduledoc """
  Functions for parsing syslog (RFC 5424) strings
  """

  @doc """
  Parse out the syslog facility, severity, and message (including the timestamp
  and host) from a syslog-formatted string.
  """
  @spec parse_syslog(String.t()) ::
          %{facility: atom(), severity: atom(), message: binary()}
          | {:error, :not_syslog_format}
  def parse_syslog(data) do
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
end
