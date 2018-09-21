defmodule Nerves.Runtime.UBootEnvTest do
  use ExUnit.Case
  doctest Nerves.Runtime.UBootEnv
  doctest Nerves.Runtime.KV.UBootEnv

  @fixtures Path.expand("fixtures", __DIR__)

  alias Nerves.Runtime.UBootEnv

  test "parse kv" do
    kv_raw = """
    a.nerves_fw_application_part0_devpath=/dev/mmcblk0p3
    a.nerves_fw_application_part0_fstype=ext4
    a.nerves_fw_application_part0_target=/root
    a.nerves_fw_architecture=arm
    a.nerves_fw_author=The Nerves Team
    a.nerves_fw_description=
    a.nerves_fw_platform=rpi
    a.nerves_fw_product=Nerves Firmware
    a.nerves_fw_version=
    nerves_fw_active=a
    nerves_fw_devpath=/dev/mmcblk0
    """

    kv = %{
      "a.nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
      "a.nerves_fw_application_part0_fstype" => "ext4",
      "a.nerves_fw_application_part0_target" => "/root",
      "a.nerves_fw_architecture" => "arm",
      "a.nerves_fw_author" => "The Nerves Team",
      "a.nerves_fw_description" => "",
      "a.nerves_fw_platform" => "rpi",
      "a.nerves_fw_product" => "Nerves Firmware",
      "a.nerves_fw_version" => "",
      "nerves_fw_active" => "a",
      "nerves_fw_devpath" => "/dev/mmcblk0"
    }

    assert UBootEnv.Tools.decode(kv_raw) == kv
  end

  test "can parse fw_env.config for common systems" do
    {:ok, config} =
      Path.join(@fixtures, "fw_env.config")
      |> UBootEnv.Config.read()

    assert {"/dev/mmcblk0", 0x100000, 0x2000} == config
  end

  test "can parse fw_env.config with spaces" do
    {:ok, config} =
      Path.join(@fixtures, "spaces_fw_env.config")
      |> UBootEnv.Config.read()

    assert {"/dev/mtd3", 0x0, 0x1000} == config
  end

  test "can parse u-boot tools created environment" do
    dev_name = Path.join(@fixtures, "fixture_uboot.bin")
    dev_offset = 0x1000
    env_size = 0x2000

    {:ok, kv} = UBootEnv.load(dev_name, dev_offset, env_size)

    assert Map.get(kv, "nerves_serial_number") == "12345"
    assert Map.get(kv, "a.nerves_fw_application_part0_devpath") == "/dev/mmcblk0p4"
  end

  test "can parse fwup-created environment" do
    dev_name = Path.join(@fixtures, "fixture_fwup.bin")
    dev_offset = 0x1000
    env_size = 0x2000

    {:ok, kv} = UBootEnv.load(dev_name, dev_offset, env_size)

    assert Map.get(kv, "nerves_serial_number") == "112233"
    assert Map.get(kv, "a.nerves_fw_application_part0_devpath") == "/dev/mmcblk0p4"
  end

  test "can encode environment" do
    dev_name = Path.join(@fixtures, "fixture_fwup.bin")
    dev_offset = 0x1000
    env_size = 0x2000

    {:ok, kv} = UBootEnv.load(dev_name, dev_offset, env_size)
    {:ok, fd} = File.open(dev_name)

    {:ok, bin} = :file.pread(fd, dev_offset, env_size)
    encoded = UBootEnv.encode(kv, env_size)
    assert bin == encoded
  end
end
