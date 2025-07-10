# SPDX-FileCopyrightText: 2025 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.StartupGuardTest do
  use ExUnit.Case, async: false
  use Mimic
  import ExUnit.CaptureLog
  alias Nerves.Runtime.StartupGuard

  require Logger

  describe "heart callback tests" do
    test "returns :ok when uptime is less than give up minutes" do
      capture_log(fn ->
        for uptime <- 0..14 do
          assert StartupGuard.do_heart_check(uptime) == :ok
        end
      end)
    end

    test "warns once a minute when up for 2 minutes" do
      assert capture_log(fn -> StartupGuard.do_heart_check(2) end) =~
               "Firmware not validated. Check logs. Rebooting in 13 minutes if unfixed."

      assert capture_log(fn -> StartupGuard.do_heart_check(2) end) == ""

      assert capture_log(fn -> StartupGuard.do_heart_check(3) end) =~
               "Firmware not validated. Check logs. Rebooting in 12 minutes if unfixed."

      assert capture_log(fn -> StartupGuard.do_heart_check(3) end) == ""
    end

    test "returns error after give up minutes" do
      capture_log(fn ->
        assert StartupGuard.do_heart_check(15) == :error
        assert StartupGuard.do_heart_check(100) == :error
      end)
    end
  end

  describe "firmware health checks" do
    test "run/1 sets up heart callback and clears on success" do
      # Expect the heart-related calls
      Mimic.expect(:heart, :set_callback, fn m, f ->
        assert m == Nerves.Runtime.StartupGuard and f == :heart_check
        :ok
      end)

      Mimic.expect(:heart, :clear_callback, fn -> :ok end)
      Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)

      # Don't check the others in this test
      Mimic.stub(Nerves.Runtime, :get_expected_started_apps, fn -> {:ok, []} end)
      Mimic.stub(Nerves.Runtime, :firmware_validation_status, fn -> :validated end)

      _ =
        capture_log(fn ->
          assert StartupGuard.run(retry_delay: 1) == :ok
        end)
    end

    test "run/1 retries getting started apps" do
      # Standard heart callbacks
      Mimic.expect(:heart, :set_callback, fn _m, _f -> :ok end)
      Mimic.expect(:heart, :clear_callback, fn -> :ok end)
      Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)

      # Fail the first attempt
      Mimic.expect(Nerves.Runtime, :get_expected_started_apps, 1, fn -> :error end)
      Mimic.expect(Nerves.Runtime, :get_expected_started_apps, fn -> {:ok, [:fake_app]} end)

      # Require a retry to get all started applications
      Mimic.expect(Application, :started_applications, fn -> [] end)

      Mimic.expect(Application, :started_applications, fn ->
        [{:fake_app, ~c"FakeApp", ~c"0.0.1"}]
      end)

      # Assume validated
      Mimic.expect(Nerves.Runtime, :firmware_validation_status, fn -> :validated end)
      Mimic.reject(Nerves.Runtime, :validate_firmware, 0)

      _ =
        capture_log(fn ->
          assert StartupGuard.run(retry_delay: 1) == :ok
        end)
    end
  end

  test "run/1 retries on failed firmware status checks" do
    # Standard heart callbacks
    Mimic.expect(:heart, :set_callback, fn _m, _f -> :ok end)
    Mimic.expect(:heart, :clear_callback, fn -> :ok end)
    Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)
    Mimic.stub(Nerves.Runtime, :get_expected_started_apps, fn -> {:ok, []} end)

    # Fail with unknown status quite a few times
    Mimic.expect(Nerves.Runtime, :firmware_validation_status, 5, fn -> :unknown end)
    Mimic.expect(Nerves.Runtime, :firmware_validation_status, fn -> :validated end)
    Mimic.reject(Nerves.Runtime, :validate_firmware, 0)

    _ =
      capture_log(fn ->
        assert StartupGuard.run(retry_delay: 1) == :ok
      end)
  end

  test "run/1 validates when unvalidated" do
    # Standard heart callbacks
    Mimic.expect(:heart, :set_callback, fn _m, _f -> :ok end)
    Mimic.expect(:heart, :clear_callback, fn -> :ok end)
    Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)
    Mimic.stub(Nerves.Runtime, :get_expected_started_apps, fn -> {:ok, []} end)

    Mimic.expect(Nerves.Runtime, :firmware_validation_status, fn -> :unvalidated end)
    Mimic.expect(Nerves.Runtime, :validate_firmware, fn -> :ok end)

    _ =
      capture_log(fn ->
        assert StartupGuard.run(retry_delay: 1) == :ok
      end)
  end

  test "run/1 raises when retrying too many times" do
    # Standard heart callbacks
    Mimic.expect(:heart, :set_callback, fn _m, _f -> :ok end)
    Mimic.expect(Nerves.Runtime.Heart, :init_complete, fn -> :ok end)

    # Never work
    Mimic.stub(Nerves.Runtime, :get_expected_started_apps, fn -> :error end)

    assert_raise RuntimeError, fn ->
      StartupGuard.run(retry_delay: 1)
    end
  end
end
