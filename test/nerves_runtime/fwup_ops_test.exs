defmodule NervesRuntime.FwupOpsTest do
  use ExUnit.Case

  alias Nerves.Runtime.FwupOps

  setup context do
    ops_fw_path = Path.expand("test/fixture/#{context[:ops_fw] || "ops-status.fw"}")
    devpath = Path.expand("tmp/#{context[:test]}/disk.img")
    _ = File.rm(devpath)
    _ = File.mkdir_p!(Path.dirname(devpath))

    [fwup_options: [devpath: devpath, ops_fw_path: ops_fw_path, reboot: false]]
  end

  defp read_output(context) do
    File.read!(context.fwup_options[:devpath]) |> String.split("\n") |> List.first()
  end

  describe "revert/1" do
    test "success", context do
      assert :ok = FwupOps.revert(context.fwup_options)
      assert read_output(context) == "revert"
    end

    @tag ops_fw: "ops-fail.fw"
    test "failure", context do
      assert {:error, "revert error"} = FwupOps.revert(context.fwup_options)
    end
  end

  describe "factory_reset/1" do
    test "success", context do
      assert :ok = FwupOps.factory_reset(context.fwup_options)
      assert read_output(context) == "factory-reset"
    end

    @tag ops_fw: "ops-fail.fw"
    test "failure", context do
      assert {:error, "factory-reset error"} = FwupOps.factory_reset(context.fwup_options)
    end
  end

  describe "validate/1" do
    test "success", context do
      assert :ok = FwupOps.validate(context.fwup_options)
      assert read_output(context) == "validate"
    end

    @tag ops_fw: "missing_ops.fw"
    test "missing ops.fw", context do
      assert {:error, "ops.fw or revert.fw not found in Nerves system"} =
               FwupOps.validate(context.fwup_options)
    end

    test "missing fwup", context do
      fwup_options = Keyword.put(context.fwup_options, :fwup_path, "/does/not/exist/fwup")

      assert {:error, "can't find fwup"} = FwupOps.validate(fwup_options)
    end

    @tag ops_fw: "ops-fail.fw"
    test "failure", context do
      assert {:error, "validate error"} = FwupOps.validate(context.fwup_options)
    end
  end

  describe "prevent_revert/1" do
    test "success", context do
      assert :ok = FwupOps.prevent_revert(context.fwup_options)
      assert read_output(context) == "prevent-revert"
    end

    @tag ops_fw: "ops-fail.fw"
    test "failure", context do
      assert {:error, "prevent-revert error"} = FwupOps.prevent_revert(context.fwup_options)
    end
  end

  describe "status/1" do
    defp fwup_status(context, status) do
      opts = Keyword.put(context.fwup_options, :fwup_env, %{"STATUS" => status})
      FwupOps.status(opts)
    end

    test "success", context do
      # ops-status.conf lets you set the status via $STATUS
      assert {:ok, %{current: "a", next: "b"}} = fwup_status(context, "a->b")
      assert {:ok, %{current: "b", next: "a"}} = fwup_status(context, "b->a")
      assert {:ok, %{current: "c", next: "c"}} = fwup_status(context, "c")
      assert {:error, "Invalid status"} = fwup_status(context, "xyz")
    end

    @tag ops_fw: "ops-fail.fw"
    test "failure", context do
      assert {:error, "status error"} = FwupOps.status(context.fwup_options)
    end
  end
end
