defmodule LogTailerTest do
  use ExUnit.Case
  doctest Nerves.Runtime.LogTailer

  alias Nerves.Runtime.LogTailer

  describe "parse_syslog_message" do
    test "parses syslog priority codes" do
      assert :kernel ==
        "<0>Test Message"
        |> LogTailer.parse_syslog_message
        |> Map.get(:facility)

      assert :Emergency ==
        "<0>Test Message"
        |> LogTailer.parse_syslog_message
        |> Map.get(:severity)

      assert :user_level ==
        "<13>Test Message"
        |> LogTailer.parse_syslog_message
        |> Map.get(:facility)

      assert :Notice ==
        "<13>Test Message"
        |> LogTailer.parse_syslog_message
        |> Map.get(:severity)

      assert :local2 ==
        "<150>Test Message"
        |> LogTailer.parse_syslog_message
        |> Map.get(:facility)

      assert :Informational ==
        "<150>Test Message"
        |> LogTailer.parse_syslog_message
        |> Map.get(:severity)
    end

    test "returns an error tuple if it can't parse" do
      assert {:error, :not_syslog_format} == LogTailer.parse_syslog_message("<beef>Test Message")
    end

    test "parses the message without the syslog priority code" do
      assert %{message: "[    0.000000] Booting Linux on physical CPU 0x0"} =
        LogTailer.parse_syslog_message("<6>[    0.000000] Booting Linux on physical CPU 0x0")

      assert %{message: "Jan  1 00:25:42 root: Test Message"} =
        LogTailer.parse_syslog_message("<13>Jan  1 00:25:42 root: Test Message")
    end
  end
end
