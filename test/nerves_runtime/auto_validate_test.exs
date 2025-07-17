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

  test "run/1 sets up heart callback" do
    Mimic.stub(:heart, :set_callback, fn _m, _f -> :ok end)
    Mimic.stub(:heart, :clear_callback, fn -> :ok end)
    Mimic.stub(Nerves.Runtime, :get_expected_started_apps, fn -> {:ok, []} end)

    Mimic.stub(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)
    Mimic.stub(Nerves.Runtime, :firmware_validation_status, fn -> :unvalidated end)
    Mimic.stub(Nerves.Runtime, :validate_firmware, fn -> :ok end)

    assert AutoValidate.run([]) == :ok

    Mimic.verify!()
  end

  # describe "register_callback/1" do
  #   test "always returns :ok" do
  #     # We can't easily test the heart interaction due to sticky modules,
  #     # but we can verify the function doesn't crash and returns :ok
  #     # Skip the actual heart call since we can't mock it
  #     # assert AutoValidate.register_callback([]) == :ok

  #     # Instead, test that the function is callable
  #     assert is_function(&AutoValidate.register_callback/1)
  #   end
  # end

  # describe "check/0 with mocked dependencies" do
  #   # Since we can't mock :init and :erlang easily, we'll test individual logic components
  #   # by testing what we can control and using module attributes for constants

  #   test "timeout calculation works correctly" do
  #     # Test the minute conversion logic
  #     minute_in_ms = 60 * 1000
  #     assert minute_in_ms == 60_000

  #     # Simulate uptime calculations
  #     two_minutes = 2 * minute_in_ms
  #     fifteen_minutes = 15 * minute_in_ms

  #     assert div(two_minutes, minute_in_ms) == 2
  #     assert div(fifteen_minutes, minute_in_ms) == 15
  #   end

  #   test "broken apps logic with controlled inputs" do
  #     # Copy modules to enable mocking with Mimic
  #     Application |> copy()

  #     # Set up expected apps in cache
  #     expected_apps = [:kernel, :stdlib, :my_app]
  #     Process.put(@cache_key, {:ok, expected_apps})

  #     # Mock actual started apps (missing :my_app)
  #     Application
  #     |> stub(:started_applications, fn ->
  #       [{:kernel, :description, :version}, {:stdlib, :description, :version}]
  #     end)

  #     # We can't easily test the full check/0 function due to sticky modules,
  #     # but we can test the broken apps logic indirectly
  #     started_apps = Application.started_applications() |> Enum.map(&elem(&1, 0))
  #     broken = expected_apps -- started_apps

  #     assert broken == [:my_app]
  #   end

  #   test "caching behavior with process dictionary" do
  #     # Test the caching mechanism directly
  #     test_fun = fn -> {:ok, [:test_app]} end

  #     # First call should execute function and cache result
  #     refute Process.get(@cache_key)

  #     # Simulate the caching logic from the module
  #     case Process.get(@cache_key) do
  #       r when r in [nil, :error] ->
  #         result = test_fun.()
  #         Process.put(@cache_key, result)
  #         assert result == {:ok, [:test_app]}
  #     end

  #     # Verify cached value
  #     assert Process.get(@cache_key) == {:ok, [:test_app]}

  #     # Second access should use cache (we can verify the cache is used)
  #     cached_result = Process.get(@cache_key)
  #     assert cached_result == {:ok, [:test_app]}
  #   end

  #   test "warning suppression logic" do
  #     # Test the warning deduplication logic
  #     current_minute = 5

  #     # First warning for this minute
  #     refute Process.get(@warned_key)
  #     Process.put(@warned_key, current_minute)
  #     assert Process.get(@warned_key) == current_minute

  #     # Same minute should be suppressed (this simulates the check in the module)
  #     should_warn = Process.get(@warned_key) != current_minute
  #     refute should_warn

  #     # Different minute should trigger warning
  #     next_minute = 6
  #     should_warn_next = Process.get(@warned_key) != next_minute
  #     assert should_warn_next
  #   end
  # end

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
