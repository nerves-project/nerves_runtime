# SPDX-FileCopyrightText: 2023 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule NervesRuntime.FwupOpsTest do
  use ExUnit.Case

  alias Nerves.Runtime.FwupOps

  @fwup_options [
    fwup_path: System.find_executable("fwup"),
    devpath: Path.expand("test/fixture/empty.img"),
    reboot: false
  ]

  @fwup_fail_options [ops_fw_path: Path.expand("test/fixture/ops-fail.fw")] ++ @fwup_options

  setup do
    # Even though this can be specified via an option, use the Application environment
    # since that's how it's normally set in practice.
    Application.put_env(:nerves_runtime, :ops_fw_path, Path.expand("test/fixture/ops.fw"))
    :ok
  end

  defp read_output() do
    File.read!(@fwup_options[:devpath]) |> String.split("\n") |> List.first()
  end

  test "revert" do
    assert :ok = FwupOps.revert(@fwup_options)
    assert read_output() == "revert"

    assert {:error, "revert error"} = FwupOps.revert(@fwup_fail_options)
  end

  test "factory reset" do
    assert :ok = FwupOps.factory_reset(@fwup_options)
    assert read_output() == "factory-reset"

    assert {:error, "factory-reset error"} = FwupOps.factory_reset(@fwup_fail_options)
  end

  test "validate" do
    assert :ok = FwupOps.validate(@fwup_options)
    assert read_output() == "validate"

    assert {:error, "validate error"} = FwupOps.validate(@fwup_fail_options)
  end

  test "prevent_revert" do
    assert :ok = FwupOps.prevent_revert(@fwup_options)
    assert read_output() == "prevent-revert"

    assert {:error, "prevent-revert error"} = FwupOps.prevent_revert(@fwup_fail_options)
  end

  defp status_ops(status) do
    Keyword.put(@fwup_options, :fwup_env, %{"STATUS" => status})
  end

  test "status" do
    # ops.conf lets you set the status via $STATUS
    assert {:ok, %{current: "a", next: "b"}} = FwupOps.status(status_ops("a->b"))
    assert {:ok, %{current: "b", next: "a"}} = FwupOps.status(status_ops("b->a"))
    assert {:ok, %{current: "c", next: "c"}} = FwupOps.status(status_ops("c"))
    assert {:error, "Invalid status"} = FwupOps.status(status_ops("xyz"))

    assert {:error, "status error"} = FwupOps.status(@fwup_fail_options)
  end

  test "missing ops.fw" do
    Application.put_env(:nerves_runtime, :ops_fw_path, "/does/not/exist/missing_ops.fw")

    assert {:error, "ops.fw or revert.fw not found in Nerves system"} =
             FwupOps.validate(@fwup_options)
  end

  test "missing fwup" do
    Application.put_env(:nerves_runtime, :fwup_path, "/does/not/exist/fwup")
    fwup_options = Keyword.drop(@fwup_options, [:fwup_path])

    assert {:error, _} = FwupOps.validate(fwup_options)
  end
end
