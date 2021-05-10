defmodule Nerves.Runtime.KVTest do
  use ExUnit.Case, async: false
  doctest Nerves.Runtime.KV

  alias Nerves.Runtime.KV

  @kv %{
    "a.nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
    "a.nerves_fw_application_part0_fstype" => "ext4",
    "a.nerves_fw_application_part0_target" => "/root",
    "a.nerves_fw_architecture" => "arm",
    "a.nerves_fw_author" => "The Nerves Team",
    "a.nerves_fw_description" => "",
    "a.nerves_fw_misc" => "",
    "a.nerves_fw_platform" => "rpi0",
    "a.nerves_fw_product" => "test_app",
    "a.nerves_fw_uuid" => "d9492bdb-94de-5288-425e-2de6928ef99c",
    "a.nerves_fw_vcs_identifier" => "",
    "a.nerves_fw_version" => "0.1.0",
    "b.nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
    "b.nerves_fw_application_part0_fstype" => "ext4",
    "b.nerves_fw_application_part0_target" => "/root",
    "b.nerves_fw_architecture" => "arm",
    "b.nerves_fw_author" => "The Nerves Team",
    "b.nerves_fw_description" => "",
    "b.nerves_fw_misc" => "",
    "b.nerves_fw_platform" => "rpi0",
    "b.nerves_fw_product" => "test_app",
    "b.nerves_fw_uuid" => "4e08ad59-fa3c-5498-4a58-179b43cc1a25",
    "b.nerves_fw_vcs_identifier" => "",
    "b.nerves_fw_version" => "0.1.1",
    "nerves_fw_active" => "b",
    "nerves_fw_devpath" => "/dev/mmcblk0",
    "nerves_serial_number" => ""
  }

  setup_all do
    Application.stop(:nerves_runtime)

    on_exit(fn ->
      Application.start(:nerves_runtime)
    end)
  end

  setup do
    {:ok, _pid} = KV.start_link(@kv)
    :ok
  end

  test "can get single value from kv" do
    assert KV.get("nerves_fw_active") == "b"
  end

  test "can get all values from kv" do
    assert KV.get_all() == @kv
  end

  test "can get all active values from kv" do
    active = Map.get(@kv, "nerves_fw_active")

    active_values =
      @kv
      |> Enum.filter(&String.starts_with?(elem(&1, 0), active))
      |> Enum.map(&{String.trim_leading(elem(&1, 0), active <> "."), elem(&1, 1)})
      |> Enum.into(%{})

    assert KV.get_all_active() == active_values
  end

  test "can get single active value from kv" do
    active_value = Map.get(@kv, "b.nerves_fw_version")
    assert KV.get_active("nerves_fw_version") == active_value
  end
end
