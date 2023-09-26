defmodule NervesRuntime.FwupOpsTest do
  use ExUnit.Case

  alias Nerves.Runtime.FwupOps

  setup do
    Application.put_env(:nerves_runtime, :fwup_path, fixture_path("fwup"))
    Application.put_env(:nerves_runtime, :revert_fw_path, fixture_path("ops.fw"))

    on_exit(fn -> File.rm("fwup-args") end)
  end

  test "revert" do
    assert :ok = FwupOps.revert(reboot: false)

    assert fwup_args() ==
             "#{fixture_path("ops.fw")} -t revert -d /dev/rootdisk0 -q -U --enable-trim"
  end

  test "factory reset" do
    assert :ok = FwupOps.factory_reset(reboot: false)

    assert fwup_args() ==
             "#{fixture_path("ops.fw")} -t factory-reset -d /dev/rootdisk0 -q -U --enable-trim"
  end

  test "validate" do
    assert :ok = FwupOps.validate()

    assert fwup_args() ==
             "#{fixture_path("ops.fw")} -t validate -d /dev/rootdisk0 -q -U --enable-trim"
  end

  test "prevent_revert" do
    assert :ok = FwupOps.prevent_revert()

    assert fwup_args() ==
             "#{fixture_path("ops.fw")} -t prevent-revert -d /dev/rootdisk0 -q -U --enable-trim"
  end

  test "missing ops.fw" do
    Application.put_env(:nerves_runtime, :revert_fw_path, fixture_path("missing_ops.fw"))

    assert {:error, _} = FwupOps.validate()
  end

  test "missing fwup" do
    Application.put_env(:nerves_runtime, :fwup_path, "/does/not/exist/fwup")

    assert {:error, _} = FwupOps.validate()
  end

  defp fwup_args() do
    File.read!("fwup-args")
  end

  defp fixture_path(relative_path) do
    Path.expand(relative_path, "test/fixture")
  end
end
