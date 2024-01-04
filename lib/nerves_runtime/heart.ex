defmodule Nerves.Runtime.Heart do
  @moduledoc """
  Functions for querying Nerves Heart and the device's watchdog

  Nerves Heart integrates Erlang's
  [heart](https://www.erlang.org/doc/man/heart.html) process with a hardware
  watchdog.  This makes it possible for a device to recover from a hang. The
  way it works is that the Erlang runtime regularly checks that it's ok. If so,
  it sends a message to `heart`. Nerves heart then pets the hardware watchdog.
  If messages ever stop being sent to `heart`, the hardware watchdog will trip
  and reboot the device. You can add additional health checks for your
  application by providing a callback to `:heart.set_callback/2`.

  See [nerves_heart](https://github.com/nerves-project/nerves_heart) for more
  information.
  """

  @typedoc """
  Nerves Heart's current status

  See [nerves_heart](https://github.com/nerves-project/nerves_heart) for more
  information.
  """
  require Logger

  @type info() :: info_v2() | info_v1()

  @typedoc """
  Nerves Heart v2.x information
  """
  @type info_v2() :: %{
          program_name: String.t(),
          program_version: Version.t(),
          heartbeat_timeout: non_neg_integer(),
          heartbeat_time_left: non_neg_integer(),
          init_handshake_happened: boolean(),
          init_handshake_timeout: non_neg_integer(),
          init_handshake_time_left: non_neg_integer(),
          init_grace_time_left: non_neg_integer(),
          snooze_time_left: non_neg_integer(),
          wdt_identity: String.t(),
          wdt_firmware_version: non_neg_integer(),
          wdt_last_boot: :power_on | :watchdog,
          wdt_options: non_neg_integer() | [atom()],
          wdt_pet_time_left: non_neg_integer(),
          wdt_pre_timeout: non_neg_integer(),
          wdt_timeout_left: non_neg_integer(),
          wdt_timeout: non_neg_integer()
        }

  @typedoc """
  Nerves Heart v1.x information
  """
  @type info_v1() :: %{
          program_name: String.t(),
          program_version: Version.t(),
          identity: String.t(),
          firmware_version: non_neg_integer(),
          options: non_neg_integer() | [atom()],
          time_left: non_neg_integer(),
          pre_timeout: non_neg_integer(),
          timeout: non_neg_integer(),
          last_boot: :power_on | :watchdog,
          heartbeat_timeout: non_neg_integer()
        }

  @doc """
  Return whether Nerves heart is running

  If you're using a Nerves device, this always returns `true` except possibly
  when porting Nerves to new hardware. It is a quick sanity check.
  """
  @spec running?() :: boolean()
  def running?() do
    case status() do
      {:ok, %{program_name: "nerves_heart"}} -> true
      _ -> false
    end
  end

  @doc """
  Notify Nerves heart that initialization is complete

  This can be used to ensure that the code that calls `:heart.set_callback/2`
  gets run. To use, add the following to your projects `rel/vm.args.eex`:

  ```text
  ## Require an initialization handshake within 15 minutes
  -env HEART_INIT_TIMEOUT 900
  ```

  Then call `Nerves.Runtime.Heart.init_complete/0` after
  `:heart.set_callback/2` is called.

  Supported by Nerves Heart v2.0 and later
  """
  @spec init_complete() :: :ok
  def init_complete() do
    # This must be run in another thread to avoid blocking the current
    # thread when it is involved in the heart callback.
    {:ok, _} =
      Task.start(fn ->
        with {:error, reason} <- run_command(~c"init_handshake", "~> 2.0") do
          Logger.error("Heart: handshake failed due to #{reason}")
        end
      end)

    :ok
  end

  @doc """
  Initiate a reboot that's guarded by the hardware watchdog

  Most users should call `Nerves.Runtime.reboot/0` instead which calls this and
  shuts down the Erlang VM.

  Support with Nerves Heart v2.0 and later.
  """
  @spec guarded_reboot() :: :ok | {:error, atom()}
  def guarded_reboot() do
    run_command(~c"guarded_reboot", "~> 2.0")
  end

  @doc """
  Initiate a poweroff that's guarded by the hardware watchdog

  Most users should call `Nerves.Runtime.poweroff/0` instead which calls this
  and shuts down the Erlang VM.

  Support with Nerves Heart v2.0 and later.
  """
  @spec guarded_poweroff() :: :ok | {:error, atom()}
  def guarded_poweroff() do
    run_command(~c"guarded_poweroff", "~> 2.0")
  end

  @doc """
  Immediately reboot without any cleanup

  WARNING: This function should be used with care since it can lose data.

  Support with Nerves Heart v2.3 and later.
  """
  @spec guarded_immediate_reboot() :: :ok | {:error, atom()}
  def guarded_immediate_reboot() do
    result = run_command(~c"guarded_immediate_reboot", "~> 2.3")

    # Fall back to a graceful reboot on failure. This will probably be
    # hard to debug if it happens, so log an error and wait a bit.
    Logger.error("Heart: failed to immediately reboot (#{inspect(result)}).")
    Process.sleep(10000)
    guarded_reboot()
  end

  @doc """
  Immediately poweroff without any cleanup

  WARNING: This function should be used with care since it can lose data.

  Support with Nerves Heart v2.3 and later.
  """
  @spec guarded_immediate_poweroff() :: :ok | {:error, atom()}
  def guarded_immediate_poweroff() do
    result = run_command(~c"guarded_immediate_poweroff", "~> 2.3")

    # Fall back to a graceful poweroff on failure
    Logger.error("Heart: failed to immediately poweroff  (#{inspect(result)})")
    Process.sleep(10000)
    guarded_poweroff()
  end

  @doc """
  Snooze heart related reboots for the next 15 minutes

  Run this to buy some time if reboots from heart or hardware watchdog are
  getting in the way.

  Support with Nerves Heart v2.2 and later.
  """
  @spec snooze() :: :ok | {:error, atom()}
  def snooze() do
    with {:error, :unresponsive} <- run_command(~c"snooze", "~> 2.2") do
      # If snooze is unresponsive, that probably means that the heart callback
      # is stuck. Unfortunately, we don't know which version of heart is being
      # run either. Nerves Heart 2.2 and later support USR1. Previous versions
      # exit (all signals would exit prior to 2.2). The caller is probably
      # desperate, so give it a try.
      kill_usr1_heart()
    end
  end

  defp kill_usr1_heart() do
    case System.cmd("killall", ["-USR1", "heart"]) do
      {_, 0} -> :ok
      _ -> {:error, :failed_to_snooze}
    end
  end

  @doc """
  Return the current Nerves Heart status

  Errors are returned when not running Nerves Heart
  """
  @spec status() :: {:ok, info()} | {:error, atom()}
  def status() do
    with {:ok, cmd} <- timed_cmd(:get_cmd, []) do
      parse_cmd(cmd)
    end
  end

  @doc """
  Raising version of status/0
  """
  @spec status!() :: info()
  def status!() do
    {:ok, results} = status()
    results
  end

  defp run_command(cmd, requirement) when is_list(cmd) do
    with :ok <- check_version(requirement) do
      timed_cmd(:set_cmd, [cmd])
    end
  end

  defp check_version(requirement) do
    case status() do
      {:ok, info} ->
        if Version.match?(info.program_version, requirement) do
          :ok
        else
          {:error, :unsupported}
        end

      error ->
        error
    end
  end

  defp timed_cmd(method, args, timeout \\ 1000) do
    task = Task.async(fn -> safe_heart(method, args) end)

    case Task.yield(task, timeout) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} ->
        result

      nil ->
        Logger.warning("Heart: heart unresponsive. A heart callback is probably taking too long.")
        {:error, :unresponsive}
    end
  end

  defp safe_heart(method, args) do
    apply(:heart, method, args)
  rescue
    ArgumentError ->
      # When heart isn't running, an ArgumentError is raised
      Logger.error("Heart: Erlang heart isn't running. Check vm.args.")
      {:error, :no_heart}
  end

  @doc false
  @spec parse_cmd(list()) :: {:ok, info()} | {:error, atom()}
  def parse_cmd([]), do: {:error, :not_nerves_heart}

  def parse_cmd(cmd) when is_list(cmd) do
    result =
      for kv_str <- String.split(to_string(cmd), "\n"),
          kv = String.split(kv_str, "=", parts: 2),
          parsed = parse_attribute(kv),
          into: %{},
          do: parsed

    {:ok, result}
  rescue
    _ -> {:error, :parse_error}
  end

  # v1 and v2 parsers
  defp parse_attribute(["program_name", str]), do: {:program_name, str}
  defp parse_attribute(["program_version", str]), do: {:program_version, Version.parse!(str)}

  defp parse_attribute(["heartbeat_timeout", str]),
    do: {:heartbeat_timeout, atoi(str)}

  # v1 parsers
  defp parse_attribute(["identity", str]), do: {:identity, str}
  defp parse_attribute(["firmware_version", str]), do: {:firmware_version, atoi(str)}
  defp parse_attribute(["options", "0x" <> hex]), do: {:options, atoi(hex, 16)}
  defp parse_attribute(["options", option_list]), do: {:options, parse_option_list(option_list)}
  defp parse_attribute(["time_left", str]), do: {:time_left, atoi(str)}
  defp parse_attribute(["pre_timeout", str]), do: {:pre_timeout, atoi(str)}
  defp parse_attribute(["timeout", str]), do: {:timeout, atoi(str)}
  defp parse_attribute(["last_boot", str]), do: {:last_boot, parse_last_boot(str)}

  # v2 parsers
  defp parse_attribute(["wdt_identity", str]), do: {:wdt_identity, str}
  defp parse_attribute(["wdt_firmware_version", str]), do: {:wdt_firmware_version, atoi(str)}
  defp parse_attribute(["wdt_options", "0x" <> hex]), do: {:wdt_options, atoi(hex, 16)}

  defp parse_attribute(["wdt_options", option_list]),
    do: {:wdt_options, parse_option_list(option_list)}

  defp parse_attribute(["wdt_pet_time_left", str]), do: {:wdt_pet_time_left, atoi(str)}
  defp parse_attribute(["wdt_pre_timeout", str]), do: {:wdt_pre_timeout, atoi(str)}
  defp parse_attribute(["wdt_timeout", str]), do: {:wdt_timeout, atoi(str)}
  defp parse_attribute(["wdt_time_left", str]), do: {:wdt_time_left, atoi(str)}
  defp parse_attribute(["wdt_last_boot", str]), do: {:wdt_last_boot, parse_last_boot(str)}
  defp parse_attribute(["heartbeat_time_left", str]), do: {:heartbeat_time_left, atoi(str)}
  defp parse_attribute(["init_handshake_timeout", str]), do: {:init_handshake_timeout, atoi(str)}
  defp parse_attribute(["snooze_time_left", str]), do: {:snooze_time_left, atoi(str)}
  defp parse_attribute(["init_grace_time_left", str]), do: {:init_grace_time_left, atoi(str)}

  defp parse_attribute(["init_handshake_time_left", str]),
    do: {:init_handshake_time_left, atoi(str)}

  defp parse_attribute(["init_handshake_happened", str]),
    do: {:init_handshake_happened, parse_bool(str)}

  # unknowns
  defp parse_attribute([_unknown, _str]), do: nil
  defp parse_attribute([""]), do: nil

  # helpers
  defp atoi(str), do: String.to_integer(str)
  defp atoi(str, base), do: String.to_integer(str, base)

  defp parse_last_boot("power_on"), do: :power_on
  defp parse_last_boot("watchdog"), do: :watchdog
  defp parse_last_boot(other), do: {:unknown, other}

  defp parse_option_list(options) do
    for s <- String.split(options, ","), s != "", do: String.to_atom(s)
  end

  defp parse_bool("1"), do: true
  defp parse_bool("true"), do: true
  defp parse_bool(_), do: false
end
