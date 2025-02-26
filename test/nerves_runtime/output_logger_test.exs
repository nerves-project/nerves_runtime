# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.OutputLoggerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Nerves.Runtime.OutputLogger

  test "logs" do
    logs =
      capture_log(fn ->
        c = OutputLogger.new(:error)
        assert c == Enum.into(["abc  \ndef", "ghi", "jkl  "], c)
      end)

    assert logs =~ "[error] def\n"
    assert logs =~ "[error] ghi\n"
    assert logs =~ "[error] jkl\n"
    assert logs =~ "[error] abc\n"
  end
end
