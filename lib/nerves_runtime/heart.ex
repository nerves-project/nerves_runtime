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
  @type info() :: %{
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

  defp parse_attribute(["program_name", str]), do: {:program_name, str}
  defp parse_attribute(["program_version", str]), do: {:program_version, Version.parse!(str)}
  defp parse_attribute(["identity", str]), do: {:identity, str}
  defp parse_attribute(["firmware_version", str]), do: {:firmware_version, String.to_integer(str)}
  defp parse_attribute(["options", "0x" <> hex]), do: {:options, String.to_integer(hex, 16)}
  defp parse_attribute(["options", option_list]), do: {:options, parse_option_list(option_list)}
  defp parse_attribute(["time_left", str]), do: {:time_left, String.to_integer(str)}
  defp parse_attribute(["pre_timeout", str]), do: {:pre_timeout, String.to_integer(str)}
  defp parse_attribute(["timeout", str]), do: {:timeout, String.to_integer(str)}
  defp parse_attribute(["last_boot", str]), do: {:last_boot, parse_last_boot(str)}

  defp parse_attribute(["heartbeat_timeout", str]),
    do: {:heartbeat_timeout, String.to_integer(str)}

  defp parse_attribute([_unknown, _str]), do: nil
  defp parse_attribute([""]), do: nil

  defp parse_last_boot("power_on"), do: :power_on
  defp parse_last_boot("watchdog"), do: :watchdog
  defp parse_last_boot(other), do: {:unknown, other}

  defp parse_option_list(options) do
    for s <- String.split(options, ","), s != "", do: String.to_atom(s)
  end
end
