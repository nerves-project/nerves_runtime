defmodule NervesRuntimeTest do
  use ExUnit.Case

  alias Nerves.Runtime.KV

  setup context do
    boardid_path = Path.join(fixture_path(), context[:boardid] || "boardid")
    ops_fw_path = Path.join(fixture_path(), context[:ops_fw] || "ops.fw")
    devpath = Path.expand("tmp/#{context[:test]}/disk.img")
    _ = File.rm(devpath)
    _ = File.mkdir_p!(Path.dirname(devpath))

    nerves_runtime_options = [
      kv_backend:
        {Nerves.Runtime.KVBackend.UBootEnv,
         uboot_locations: [%{path: devpath, offset: 0, size: 32 * 512}]},
      boardid_path: boardid_path,
      ops_fw_path: ops_fw_path,
      fwup_path: System.find_executable("fwup"),
      fwup_env: %{},
      devpath: devpath
    ]

    Application.put_all_env(nerves_runtime: nerves_runtime_options)

    # Fresh start for nerves_runtime for each test
    Application.stop(:nerves_runtime)

    # Try to factory reset the U-Boot environment, but don't worry if it fails since
    # some tests don't use it.
    _ =
      System.cmd(nerves_runtime_options[:fwup_path], [
        "-a",
        "-i",
        ops_fw_path,
        "-t",
        "factory-reset",
        "-d",
        devpath,
        "-q",
        "-U"
      ])

    Application.start(:nerves_runtime)

    :ok
  end

  describe "serial number" do
    @tag boardid: "boardid"
    test "serial_number returns boardid result" do
      assert Nerves.Runtime.serial_number() == "123456789"
    end

    @tag boardid: "boardid_fail"
    test "serial_number is unconfigured on failure" do
      assert Nerves.Runtime.serial_number() == "unconfigured"
    end

    @tag boardid: "missing"
    test "serial_number is unconfigured on missing" do
      assert Nerves.Runtime.serial_number() == "unconfigured"
    end
  end

  describe "non-fwup-assisted validation" do
    # Ensure that everything fails the ops.fw way, so the fallback code is used
    @describetag ops_fw: "ops-fail.fw"

    test "firmware can be validated" do
      KV.put(%{"upgrade_available" => nil, "bootcount" => nil, "nerves_fw_validated" => "0"})
      refute Nerves.Runtime.firmware_valid?()

      Nerves.Runtime.validate_firmware()

      assert Nerves.Runtime.firmware_valid?()
      assert KV.get("nerves_fw_validated") == "1"

      # Make sure that the U-Boot bootcount variables aren't set if they're not being used
      assert KV.get("upgrade_available") == nil
      assert KV.get("bootcount") == nil
    end

    test "firmware validation using U-Boot bootcount" do
      KV.put(%{"upgrade_available" => "1", "bootcount" => "1", "nerves_fw_validated" => nil})
      refute Nerves.Runtime.firmware_valid?()

      Nerves.Runtime.validate_firmware()

      assert Nerves.Runtime.firmware_valid?()
      assert KV.get("upgrade_available") == "0"
      assert KV.get("bootcount") == "0"

      # nerves_fw_validated is set since some code in the wild still expects it
      assert KV.get("nerves_fw_validated") == "1"
    end

    test "firmware valid when not using firmware validity" do
      KV.put(%{"nerves_fw_validated" => nil})
      assert Nerves.Runtime.firmware_valid?()
    end
  end

  describe "fwup-assisted validation" do
    # Use the ops.fw that uses U-Boot variables to simulate everything.
    @describetag ops_fw: "ops.fw"

    test "validate already valid firmware" do
      # Sanity check the initial state
      assert KV.get("nerves_fw_active") == "a"
      assert KV.get("a.nerves_fw_validated") == "1"
      assert KV.get("b.nerves_fw_validated") == nil

      assert Nerves.Runtime.firmware_valid?()
      assert Nerves.Runtime.validate_firmware()

      # Check that there was no change
      assert KV.get("nerves_fw_active") == "a"
      assert KV.get("a.nerves_fw_validated") == "1"
      assert KV.get("b.nerves_fw_validated") == nil
      assert Nerves.Runtime.firmware_valid?()
    end

    test "validate new firmware" do
      # Sanity check the initial state
      assert KV.get("a.nerves_fw_validated") == "1"
      assert KV.get("b.nerves_fw_validated") == nil

      # Simulate booting "b" for the first time
      KV.put("nerves_fw_active", "b")
      refute Nerves.Runtime.firmware_valid?()

      # Validate
      assert Nerves.Runtime.validate_firmware()

      # Check that there was no change
      assert KV.get("nerves_fw_active") == "b"
      assert KV.get("a.nerves_fw_validated") == "1"
      assert KV.get("b.nerves_fw_validated") == "1"
      assert Nerves.Runtime.firmware_valid?()
    end
  end

  test "mix_target/0" do
    assert Nerves.Runtime.mix_target() == :host
  end

  defp fixture_path() do
    Path.expand("test/fixture")
  end
end
