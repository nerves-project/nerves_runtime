# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2018 Frank Hunleth
# SPDX-FileCopyrightText: 2022 Jon Carstens
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.KVTest do
  use ExUnit.Case, async: false
  doctest Nerves.Runtime.KV

  alias Nerves.Runtime.KV

  @moduletag capture_log: true

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
    "nerves_serial_number" => "123456"
  }

  setup_all do
    Application.stop(:nerves_runtime)

    on_exit(fn ->
      Application.start(:nerves_runtime)
    end)
  end

  setup context do
    options =
      context[:kv_options] || [kv_backend: {Nerves.Runtime.KVBackend.InMemory, contents: @kv}]

    if !context[:dont_start] do
      start_supervised!({KV, options})
    end

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

  test "put/2" do
    assert :ok = KV.put("test_key", "test_value")
    assert KV.get("test_key") == "test_value"
  end

  test "put/1" do
    assert :ok = KV.put(%{"test_key1" => "test_value1", "test_key2" => "test_value2"})
    assert KV.get("test_key1") == "test_value1"
    assert KV.get("test_key2") == "test_value2"
  end

  test "delete/1" do
    assert :ok = KV.put(%{"test_key1" => "test_value1", "test_key2" => "test_value2"})
    assert :ok = KV.delete("test_key1")

    all = KV.get_all()
    refute Map.has_key?(all, "test_key1")
    assert Map.has_key?(all, "test_key2")
  end

  test "put_active/2" do
    assert :ok = KV.put_active("active_test_key", "active_test_value")
    assert KV.get_active("active_test_key") == "active_test_value"
  end

  test "put_active/1" do
    assert :ok =
             KV.put_active(%{
               "active_test_key1" => "active_test_value1",
               "active_test_key2" => "active_test_value2"
             })

    assert KV.get_active("active_test_key1") == "active_test_value1"
    assert KV.get_active("active_test_key2") == "active_test_value2"
  end

  test "delete_active/1" do
    assert :ok =
             KV.put_active(%{
               "active_test_key1" => "active_test_value1",
               "active_test_key2" => "active_test_value2"
             })

    assert :ok = KV.delete_active("active_test_key1")

    all = KV.get_all()
    refute Map.has_key?(all, "b.active_test_key1")
    assert Map.has_key?(all, "b.active_test_key2")

    # These should never have existed, but sanity check.
    refute Map.has_key?(all, "a.active_test_key1")
    refute Map.has_key?(all, "a.active_test_key1")
  end

  test "reload/1" do
    # Check the basics and set the serial number to something else
    assert KV.get("nerves_serial_number") == "123456"
    KV.put("nerves_serial_number", "654321")
    assert KV.get("nerves_serial_number") == "654321"

    KV.reload()

    # Check that the serial number is back to the original value
    assert KV.get("nerves_serial_number") == "123456"
  end

  @tag kv_options: [{:modules, [{Nerves.Runtime.KV.Mock, %{"key" => "value"}}]}]
  test "old modules configuration" do
    assert KV.get("key") == "value"

    assert :ok = KV.put("test_key", "test_value")
    assert KV.get("test_key") == "test_value"
  end

  @tag kv_options: [{Nerves.Runtime.KV.Mock, %{"key" => "value"}}]
  test "old configuration" do
    assert KV.get("key") == "value"

    assert :ok = KV.put("test_key", "test_value")
    assert KV.get("test_key") == "test_value"
  end

  @tag kv_options: [kv_backend: Nerves.Runtime.KVBackend.InMemory]
  test "empty configuration" do
    assert KV.get_all() == %{}
  end

  @tag kv_options: [kv_backend: Nerves.Runtime.KVBackend.BadBad]
  test "bad configuration reverts to empty" do
    assert KV.get_all() == %{}
  end

  @tag dont_start: true
  test "application stopped" do
    assert KV.get("nerves_serial_number") == nil
    assert KV.get_active("nerves_fw_version") == nil
    assert KV.get_all() == %{}
    assert KV.get_all_active() == %{}

    assert KV.reload() == :ok

    assert {:error, "Nerves.Runtime not running"} = KV.put("test_key", "test_value")
    assert {:error, "Nerves.Runtime not running"} = KV.put_active("test_key", "test_value")
  end
end
