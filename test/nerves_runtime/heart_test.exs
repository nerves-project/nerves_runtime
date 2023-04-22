defmodule Nerves.Runtime.HeartTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Heart

  alias Nerves.Runtime.Heart

  describe "parse_cmd/1" do
    test "Raspberry Pi w/ v1 hex options" do
      cmd =
        'program_name=nerves_heart\nprogram_version=1.0.0\nidentity=Broadcom BCM2835 Watchdog timer\n' ++
          'firmware_version=0\noptions=0x00008180\ntime_left=13\npre_timeout=0\ntimeout=15\nlast_boot=power_on\n'

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

    test "BBB w/ v1 options" do
      cmd =
        'program_name=nerves_heart\nprogram_version=1.0.0\nidentity=OMAP Watchdog\nfirmware_version=0\n' ++
          'options=settimeout,magicclose,keepaliveping,\ntime_left=119\npre_timeout=0\n' ++
          'timeout=120\nlast_boot=power_on\n'

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

    test "Allwinner w/ v2 options" do
      cmd =
        'program_name=nerves_heart\nprogram_version=2.0.0\nheartbeat_timeout=30\nheartbeat_time_left=27\n' ++
          'wdt_pet_time_left=5\ninit_handshake_happened=1\ninit_handshake_timeout=0\ninit_handshake_time_left=0\n' ++
          'wdt_identity=sunxi-wdt\nwdt_firmware_version=0\nwdt_options=settimeout,magicclose,keepaliveping,\n' ++
          'wdt_time_left=0\nwdt_pre_timeout=0\nwdt_timeout=16\nwdt_last_boot=power_on\n'

      assert Heart.parse_cmd(cmd) ==
               {:ok,
                %{
                  program_name: "nerves_heart",
                  program_version: Version.parse!("2.0.0"),
                  heartbeat_time_left: 27,
                  heartbeat_timeout: 30,
                  init_handshake_happened: true,
                  init_handshake_time_left: 0,
                  init_handshake_timeout: 0,
                  wdt_firmware_version: 0,
                  wdt_identity: "sunxi-wdt",
                  wdt_last_boot: :power_on,
                  wdt_options: [:settimeout, :magicclose, :keepaliveping],
                  wdt_pre_timeout: 0,
                  wdt_timeout: 16,
                  wdt_pet_time_left: 5,
                  wdt_time_left: 0
                }}
    end

    test "RaspberryPi 3 w/ v2.2 options" do
      cmd =
        'program_name=nerves_heart\nprogram_version=2.2.0\nheartbeat_timeout=30\nheartbeat_time_left=29\n' ++
          'init_grace_time_left=0\nsnooze_time_left=0\nwdt_pet_time_left=6\ninit_handshake_happened=1\n' ++
          'init_handshake_timeout=0\ninit_handshake_time_left=0\nwdt_identity=Broadcom BCM2835 Watchdog timer\n' ++
          'wdt_firmware_version=0\nwdt_options=settimeout,magicclose,keepaliveping,\nwdt_time_left=14\n' ++
          'wdt_pre_timeout=0\nwdt_timeout=15\nwdt_last_boot=power_on\n'

      assert Heart.parse_cmd(cmd) ==
               {:ok,
                %{
                  program_name: "nerves_heart",
                  program_version: Version.parse!("2.2.0"),
                  heartbeat_time_left: 29,
                  heartbeat_timeout: 30,
                  init_handshake_happened: true,
                  init_handshake_time_left: 0,
                  init_handshake_timeout: 0,
                  wdt_firmware_version: 0,
                  wdt_identity: "Broadcom BCM2835 Watchdog timer",
                  wdt_last_boot: :power_on,
                  wdt_options: [:settimeout, :magicclose, :keepaliveping],
                  wdt_pet_time_left: 6,
                  wdt_pre_timeout: 0,
                  wdt_time_left: 14,
                  wdt_timeout: 15,
                  init_grace_time_left: 0,
                  snooze_time_left: 0
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
