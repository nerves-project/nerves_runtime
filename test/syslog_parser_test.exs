defmodule SyslogParserTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Log.Parser

  alias Nerves.Runtime.Log.Parser

  test "parses syslog codes" do
    assert :kernel ==
             "<0>Test Message"
             |> Parser.parse_syslog()
             |> Map.get(:facility)

    assert :emergency ==
             "<0>Test Message"
             |> Parser.parse_syslog()
             |> Map.get(:severity)

    assert :user_level ==
             "<13>Test Message"
             |> Parser.parse_syslog()
             |> Map.get(:facility)

    assert :notice ==
             "<13>Test Message"
             |> Parser.parse_syslog()
             |> Map.get(:severity)

    assert :local2 ==
             "<150>Test Message"
             |> Parser.parse_syslog()
             |> Map.get(:facility)

    assert :informational ==
             "<150>Test Message"
             |> Parser.parse_syslog()
             |> Map.get(:severity)
  end

  test "returns an error tuple if it can't parse" do
    assert {:error, :not_syslog_format} == Parser.parse_syslog("<beef>Test Message")
  end

  test "parses the message without the syslog priority code" do
    assert %{message: "[    0.000000] Booting Linux on physical CPU 0x0"} =
             Parser.parse_syslog("<6>[    0.000000] Booting Linux on physical CPU 0x0")

    assert %{message: "Jan  1 00:25:42 root: Test Message"} =
             Parser.parse_syslog("<13>Jan  1 00:25:42 root: Test Message")
  end
end
