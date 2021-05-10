defmodule Nerves.Runtime.Log.KmsgParserTest do
  use ExUnit.Case

  alias Nerves.Runtime.Log.KmsgParser

  test "parses kmsg reports" do
    assert {:ok,
            %{
              message: "Out of memory: Kill process 14910 (code) score 300 or sacrifice child",
              facility: :kernel,
              severity: :error,
              sequence: 7002,
              timestamp: 192_203_018_349,
              flags: []
            }} ==
             KmsgParser.parse(
               "3,7002,192203018349,-;Out of memory: Kill process 14910 (code) score 300 or sacrifice child"
             )

    assert {:ok,
            %{
              message:
                "Killed process 14910 (code) total-vm:810936kB, anon-rss:10052kB, file-rss:0kB, shmem-rss:0kB",
              facility: :kernel,
              severity: :error,
              sequence: 7003,
              timestamp: 192_203_018_400,
              flags: []
            }} ==
             KmsgParser.parse(
               "3,7003,192203018400,-;Killed process 14910 (code) total-vm:810936kB, anon-rss:10052kB, file-rss:0kB, shmem-rss:0kB"
             )

    assert {:ok,
            %{
              message:
                "oom_reaper: reaped process 14910 (code), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB",
              facility: :kernel,
              severity: :informational,
              sequence: 7004,
              timestamp: 192_203_028_735,
              flags: []
            }} ==
             KmsgParser.parse(
               "6,7004,192203028735,-;oom_reaper: reaped process 14910 (code), now anon-rss:0kB, file-rss:0kB, shmem-rss:0kB"
             )

    assert {:ok,
            %{
              message:
                "containerd invoked oom-killer: gfp_mask=0x14200ca(GFP_HIGHUSER_MOVABLE), nodemask=(null), order=0, oom_score_adj=0",
              facility: :kernel,
              severity: :warning,
              sequence: 7005,
              timestamp: 192_206_114_689,
              flags: []
            }} ==
             KmsgParser.parse(
               "4,7005,192206114689,-;containerd invoked oom-killer: gfp_mask=0x14200ca(GFP_HIGHUSER_MOVABLE), nodemask=(null), order=0, oom_score_adj=0"
             )
  end

  test "returns an error tuple if it can't parse" do
    assert {:error, :parse_error} == KmsgParser.parse("<beef>Test Message")
  end

  test "returns an error for strings it should parse, but doesn't" do
    assert {:error, :parse_error} == KmsgParser.parse(" Part of previous message")
  end
end
