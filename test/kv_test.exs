defmodule KVTest do
  use ExUnit.Case
  doctest Nerves.Runtime.KV

  alias Nerves.Runtime.KV

  test "parse kv" do
    kv_raw =
      """
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
    kv =
      %{"a.nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
        "a.nerves_fw_application_part0_fstype" => "ext4",
        "a.nerves_fw_application_part0_target" => "/root",
        "a.nerves_fw_architecture" => "arm",
        "a.nerves_fw_author" => "The Nerves Team", "a.nerves_fw_description" => "",
        "a.nerves_fw_platform" => "rpi", "a.nerves_fw_product" => "Nerves Firmware",
        "a.nerves_fw_version" => "", "nerves_fw_active" => "a",
        "nerves_fw_devpath" => "/dev/mmcblk0"}
    assert KV.parse_kv(kv_raw) == kv
  end
end
