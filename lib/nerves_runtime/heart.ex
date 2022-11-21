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
  Return whether Nerves Heart supports the v2 command/status set
  """
  @spec supports_v2?() :: boolean()
  def supports_v2?() do
    case status() do
      {:ok, %{program_version: v}} -> Version.match?(v, "~> 2.0")
      _ -> false
    end
  end

  @doc """
  Notify Nerves heart that initialization is complete

  This can be used to ensure that the code that calls `:heart.set_callback/1` gets run.
  To use, add the following to your projects `rel/vm.args.eex`:

  ```text
  ## Require an initialization handshake within 15 minutes
  -env HEART_INIT_TIMEOUT 900
  ```

  Then call `Nerves.Runtime.Heart.init_complete/0` after
  `:heart.set_callback/1` is called.

  Supported by Nerves Heart v2.0 and later
  """
  @spec init_complete() :: :ok
  def init_complete() do
    _ =
      spawn(fn ->
        if supports_v2?() do
          # This must be run in another thread to avoid blocking the current
          # thread when it is involved in the heart callback.
          :heart.set_cmd('init_handshake')
        else
          Logger.error("Initializing handshake not supported with Nerves Heart < v2.0")
        end
      end)

    :ok
  end

  @spec guarded_reboot() :: :ok | {:error, :unsupported}
  def guarded_reboot() do
    do_v2_command('guarded_reboot')
  end

  @spec guarded_poweroff() :: :ok | {:error, :unsupported}
  def guarded_poweroff() do
    do_v2_command('guarded_poweroff')
  end

  defp do_v2_command(cmd) do
    if supports_v2?() do
      :heart.set_cmd(cmd)
    else
      {:error, :unsupported}
    end
  end

  @doc """
  Return the current Nerves Heart status

  Errors are returned when not running Nerves Heart
  """
  @spec status() :: {:ok, info()} | :error
  def status() do
    {:ok, cmd} = :heart.get_cmd()

    parse_cmd(cmd)
  rescue
    ArgumentError ->
      # When heart isn't running, an ArgumentError is raised
      :error
  end

  @doc """
  Raising version of status/0
  """
  @spec status!() :: info()
  def status!() do
    {:ok, results} = status()
    results
  end

  @doc false
  @spec parse_cmd(list()) :: {:ok, info()} | :error
  def parse_cmd([]), do: :error

  def parse_cmd(cmd) when is_list(cmd) do
    result =
      cmd
      |> to_string()
      |> String.split("\n")
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.map(&parse_attribute/1)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    {:ok, result}
  rescue
    _ -> :error
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
