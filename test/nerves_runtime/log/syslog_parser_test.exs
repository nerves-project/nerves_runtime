defmodule Nerves.Runtime.Log.SyslogParserTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Log.SyslogParser

  alias Nerves.Runtime.Log.SyslogParser

  test "parses syslog messages" do
    assert {:ok, %{facility: :kernel, severity: :emergency, message: "Test Message"}} ==
             SyslogParser.parse("<0>Test Message")

    assert {:ok, %{facility: :user_level, severity: :notice, message: "Test Message"}} ==
             SyslogParser.parse("<13>Test Message")

    assert {:ok, %{facility: :local2, severity: :informational, message: "Test Message"}} ==
             SyslogParser.parse("<150>Test Message")

    assert {:ok, %{facility: :local7, severity: :debug, message: "Test Message"}} ==
             SyslogParser.parse("<191>Test Message")

    assert {:ok, %{facility: :kernel, severity: :emergency, message: ""}} ==
             SyslogParser.parse("<0>")
  end

  test "returns an error tuple if it can't parse" do
    assert {:error, :parse_error} == SyslogParser.parse("<beef>non-integer code")
    assert {:error, :parse_error} == SyslogParser.parse("<200>too large code")
    assert {:error, :parse_error} == SyslogParser.parse("<192>too large code")
    assert {:error, :parse_error} == SyslogParser.parse("<-1>negative code")
    assert {:error, :parse_error} == SyslogParser.parse("No syslog code")
  end

  test "decodes priority" do
    assert {:ok, :kernel, :emergency} == SyslogParser.decode_priority(0)
    assert {:ok, :user_level, :notice} == SyslogParser.decode_priority(13)
    assert {:ok, :local2, :informational} == SyslogParser.decode_priority(150)
    assert {:ok, :local7, :debug} == SyslogParser.decode_priority(191)
  end

  test "converts severity to logger levels" do
    assert :error == SyslogParser.severity_to_logger(:emergency)
    assert :error == SyslogParser.severity_to_logger(:alert)
    assert :error == SyslogParser.severity_to_logger(:critical)
    assert :error == SyslogParser.severity_to_logger(:error)

    assert :warn == SyslogParser.severity_to_logger(:warning)

    assert :info == SyslogParser.severity_to_logger(:notice)
    assert :info == SyslogParser.severity_to_logger(:informational)

    assert :debug == SyslogParser.severity_to_logger(:debug)
  end
end
