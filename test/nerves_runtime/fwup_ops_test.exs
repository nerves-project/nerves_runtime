defmodule NervesRuntime.FwupOpsTest do
  use ExUnit.Case

  alias Nerves.Runtime.FwupOps

  @fwup_options [
    fwup_path: System.find_executable("fwup"),
    devpath: Path.expand("test/fixture/empty.img"),
    reboot: false
  ]

  setup do
    # Even though this can be specified via an option, use the Application environment
    # since that's how it's normally set in practice.
    Application.put_env(:nerves_runtime, :revert_fw_path, Path.expand("test/fixture/ops.fw"))
    :ok
  end

  defp read_output() do
    File.read!(@fwup_options[:devpath]) |> String.split("\n") |> List.first()
  end

  test "revert" do
    assert :ok = FwupOps.revert(@fwup_options)
    assert read_output() == "revert"
  end

  test "factory reset" do
    assert :ok = FwupOps.factory_reset(@fwup_options)
    assert read_output() == "factory-reset"
  end

  test "validate" do
    assert :ok = FwupOps.validate(@fwup_options)
    assert read_output() == "validate"
  end

  test "prevent_revert" do
    assert :ok = FwupOps.prevent_revert(@fwup_options)
    assert read_output() == "prevent-revert"
  end

  test "missing ops.fw" do
    Application.put_env(:nerves_runtime, :revert_fw_path, "/does/not/exist/missing_ops.fw")

    assert {:error, "ops.fw or revert.fw not found in Nerves system"} =
             FwupOps.validate(@fwup_options)
  end

  test "missing fwup" do
    Application.put_env(:nerves_runtime, :fwup_path, "/does/not/exist/fwup")
    fwup_options = Keyword.drop(@fwup_options, [:fwup_path])

    assert {:error, _} = FwupOps.validate(fwup_options)
  end
end
