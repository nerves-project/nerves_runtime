defmodule NervesRuntimeTest do
  use ExUnit.Case

  alias Nerves.Runtime.KV

  test "serial_number returns boardid result" do
    Application.put_env(:nerves_runtime, :boardid_path, Path.join(fixture_path(), "boardid"))
    assert Nerves.Runtime.serial_number() == "123456789"
  end

  test "serial_number is unconfigured on failure" do
    Application.put_env(:nerves_runtime, :boardid_path, Path.join(fixture_path(), "boardid_fail"))
    assert Nerves.Runtime.serial_number() == "unconfigured"
  end

  test "serial_number is unconfigured on missing" do
    Application.put_env(:nerves_runtime, :boardid_path, Path.join(fixture_path(), "missing"))

    assert Nerves.Runtime.serial_number() == "unconfigured"
  end

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

  defp fixture_path() do
    Path.expand("test/fixture")
  end
end
