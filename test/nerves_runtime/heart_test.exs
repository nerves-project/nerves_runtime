defmodule Nerves.Runtime.HeartTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Heart

  alias Nerves.Runtime.Heart

  describe "parse_cmd/1" do
    test "Raspberry Pi w/ hex options" do
      cmd =
        'program_name=nerves_heart\nprogram_version=1.0.0\nidentity=Broadcom BCM2835 Watchdog timer\nfirmware_version=0\noptions=0x00008180\ntime_left=13\npre_timeout=0\ntimeout=15\nlast_boot=power_on\n'

      assert Heart.parse_cmd(cmd) ==
               {:ok,
                %{
                  program_name: "nerves_heart",
                  program_version: Version.parse!("1.0.0"),
                  identity: "Broadcom BCM2835 Watchdog timer",
                  firmware_version: 0,
                  options: 0x00008180,
                  time_left: 13,
                  pre_timeout: 0,
                  timeout: 15,
                  last_boot: :power_on
                }}
    end

    test "BBB w/ options" do
      cmd =
        'program_name=nerves_heart\nprogram_version=1.0.0\nidentity=OMAP Watchdog\nfirmware_version=0\noptions=settimeout,magicclose,keepaliveping,\ntime_left=119\npre_timeout=0\ntimeout=120\nlast_boot=power_on\n'

      assert Heart.parse_cmd(cmd) ==
               {:ok,
                %{
                  program_name: "nerves_heart",
                  program_version: Version.parse!("1.0.0"),
                  identity: "OMAP Watchdog",
                  firmware_version: 0,
                  options: [:settimeout, :magicclose, :keepaliveping],
                  time_left: 119,
                  pre_timeout: 0,
                  timeout: 120,
                  last_boot: :power_on
                }}
    end

    test "No options" do
      cmd = 'program_name=nerves_heart\nprogram_version=1.0.0\noptions=\n'

      assert Heart.parse_cmd(cmd) ==
               {:ok,
                %{
                  program_name: "nerves_heart",
                  program_version: Version.parse!("1.0.0"),
                  options: []
                }}
    end

    test "unknown field is ignored" do
      cmd = 'program_name=nerves_heart\nnew_field=1\n'

      assert Heart.parse_cmd(cmd) == {:ok, %{program_name: "nerves_heart"}}
    end

    test "Erlang heart" do
      assert :error = Heart.parse_cmd('')
      assert :error = Heart.parse_cmd('reboot')
    end

    test "parse errors" do
      assert :error = Heart.parse_cmd('program_version=1.0')
      assert :error = Heart.parse_cmd('reboot')
    end
  end
end
