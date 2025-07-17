# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.AutoValidateTest do
  use ExUnit.Case, async: false
  use Mimic
  import ExUnit.CaptureLog
  require Logger

  alias Nerves.Runtime.AutoValidate

  describe "heart callback tests" do
    test "returns :ok when uptime is less than give up minutes" do
      capture_log(fn ->
        for uptime <- 0..14 do
          assert AutoValidate.do_heart_check(uptime) == :ok
        end
      end)
    end

    test "warns once a minute when up for 2 minutes" do
      assert capture_log(fn -> AutoValidate.do_heart_check(2) end) =~
               "Firmware not validated. Check logs. Rebooting in 13 minutes if unfixed."

      assert capture_log(fn -> AutoValidate.do_heart_check(2) end) == ""

      assert capture_log(fn -> AutoValidate.do_heart_check(3) end) =~
               "Firmware not validated. Check logs. Rebooting in 12 minutes if unfixed."

      assert capture_log(fn -> AutoValidate.do_heart_check(3) end) == ""
    end

    test "returns error after give up minutes" do
      capture_log(fn ->
        assert AutoValidate.do_heart_check(15) == :error
        assert AutoValidate.do_heart_check(100) == :error
      end)
    end
  end

  describe "firmware health checks" do
    test "run/1 sets up heart callback and clears on success" do
      # Expect the heart-related calls
      Mimic.expect(:heart, :set_callback, fn m, f ->
        assert m == Nerves.Runtime.AutoValidate and f == :heart_check
        :ok
      end)

      Mimic.expect(:heart, :clear_callback, fn -> :ok end)
      Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)

      # Don't check the others in this test
      Mimic.stub(Nerves.Runtime, :get_expected_started_apps, fn -> {:ok, []} end)
      Mimic.stub(Nerves.Runtime, :firmware_validation_status, fn -> :validated end)

      _ =
        capture_log(fn ->
          assert AutoValidate.run([]) == :ok
        end)

      Mimic.verify!()
    end

    test "run/1 retries getting the expected started apps" do
      # Standard heart callbacks
      Mimic.expect(:heart, :set_callback, fn _m, _f -> :ok end)
      Mimic.expect(:heart, :clear_callback, fn -> :ok end)
      Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)

      # Fail the first attempt
      Mimic.expect(Nerves.Runtime, :get_expected_started_apps, 1, fn -> :error end)
      Mimic.expect(Nerves.Runtime, :get_expected_started_apps, fn ->        {:ok, []}      end)

      Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)

      _ =
        capture_log(fn ->
          assert AutoValidate.run([]) == :ok
        end)

      Mimic.verify!()
    end
  end

  # describe "boot script parsing" do
  #   test "handles mixed instructions" do
  #     boot_instructions = [
  #       {:apply, {:application, :start_boot, [:kernel]}},
  #       {:kernel_load_completed},
  #       {:apply, {:application, :start_boot, [:stdlib, :permanent]}},
  #       {:progress, :applications_loaded},
  #       {:apply, {:application, :start_boot, [:my_app, :temporary]}}
  #     ]

  #     apps = for {:apply, {:application, :start_boot, [app | _]}} <- boot_instructions, do: app
  #     assert apps == [:kernel, :stdlib, :my_app]
  #   end
  # end

  # describe "firmware validation logic" do
  #   test "handles validation success" do
  #     Nerves.Runtime |> copy()

  #     Nerves.Runtime
  #     |> stub(:validate_firmware, fn -> :ok end)

  #     # Test that validate_firmware returns :ok when stubbed
  #     result = Nerves.Runtime.validate_firmware()
  #     assert result == :ok
  #   end

  #   test "handles validation failure" do
  #     Nerves.Runtime |> copy()

  #     Nerves.Runtime
  #     |> stub(:validate_firmware, fn -> {:error, :some_reason} end)

  #     # Test that validate_firmware returns error when stubbed
  #     result = Nerves.Runtime.validate_firmware()
  #     assert result == {:error, :some_reason}
  #   end
  # end
end
