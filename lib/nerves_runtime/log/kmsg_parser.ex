defmodule Nerves.Runtime.Log.KmsgParser do
  @moduledoc """
  Functions for parsing kmsg strings
  """

  alias Nerves.Runtime.Log.SyslogParser

  @doc """
  Parse out the kmsg facility, severity, and message (including the timestamp
  and host) from a kmsg-formatted string.

  See https://elixir.bootlin.com/linux/latest/source/Documentation/ABI/testing/dev-kmsg for full details.

  Most messages are of the form:

  ```text
  priority,sequence,timestamp,flag;message
  ```

  `priority` is an integer that when broken apart gives you a facility and severity.
  `sequence` is a monotonically increasing counter
  `timestamp` is the time in microseconds
  `flag` is almost always `-`
  `message` is everything else

  This parser only supports the minimum kmsg reports. The spec above describes
  more functionality, but it appears to be uncommon and I haven't seen any
  examples yet in my testing.
  """
  @spec parse(String.t()) ::
          {:ok,
           %{
             facility: SyslogParser.facility(),
             severity: SyslogParser.severity(),
             message: String.t(),
             timestamp: integer(),
             sequence: integer(),
             flags: [atom()]
           }}
          | {:error, :parse_error}
  def parse(line) do
    with [metadata, message] <- String.split(line, ";"),
         [priority_str, sequence_str, timestamp_str, flag] <-
           String.split(metadata, ",", parts: 4),
         {priority_int, ""} <- Integer.parse(priority_str),
         {sequence, ""} <- Integer.parse(sequence_str),
         {timestamp, ""} <- Integer.parse(timestamp_str),
         {:ok, facility, severity} <- SyslogParser.decode_priority(priority_int) do
      {:ok,
       %{
         facility: facility,
         severity: severity,
         message: message,
         timestamp: timestamp,
         sequence: sequence,
         flags: parse_flags(flag)
       }}
    else
      _ -> {:error, :parse_error}
    end
  end

  defp parse_flags("-"), do: []
  defp parse_flags("c"), do: [:continue]
  defp parse_flags(_), do: []
end
