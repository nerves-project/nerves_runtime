defmodule NervesRuntimeTest do
  use ExUnit.Case

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
    refute Nerves.Runtime.firmware_valid?()

    Nerves.Runtime.validate_firmware()

    assert Nerves.Runtime.firmware_valid?()
  end

  defp fixture_path() do
    Path.expand("test/fixture")
  end
end
