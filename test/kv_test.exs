defmodule KVTest do
  use ExUnit.Case
  doctest Nerves.Runtime.KV

  @fixtures Path.expand("fixtures", __DIR__)

  alias Nerves.Runtime.KV

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

    assert KV.parse_kv(kv_raw) == kv
  end

  test "can parse fw_env.config for common systems" do
    {:ok, config} =
      Path.join(@fixtures, "fw_env.config")
      |> KV.read_config()

    assert {"/dev/mmcblk0", 0x100000, 0x2000} = KV.parse_config(config)
  end

  test "can parse fw_env.config with spaces" do
    {:ok, config} =
      Path.join(@fixtures, "spaces_fw_env.config")
      |> KV.read_config()

    assert {"/dev/mtd3", 0x0, 0x1000} = KV.parse_config(config)
  end
end
