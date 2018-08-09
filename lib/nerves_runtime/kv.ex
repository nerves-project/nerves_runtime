defmodule Nerves.Runtime.KV do
  @moduledoc """
  Key Value Storage for firmware vairables provided by fwup

  KV provides access to metadata variables set by fwup.
  It can be used to obtain information such as the active
  firmware slot, where the application data partition
  is located, etc.

  Values are stored in two ways.
  * Values that do not pertain to a specific firmware slot
  For example:
    `"nerves_fw_active" => "a"`

  * Values that pertain to a specific firmware slot
  For Example:
    `"a.nerves_fw_author" => "The Nerves Team"`

  You can find values for just the active firmware slot by
  using get_active and get_all_active. The result of these
  functions will trim the firmware slot (`"a."` or `"b."`)
  from the leading characters of the keys returned.

  ## Technical Information

  Nerves.Runtime.KV uses a non-replicated U-Boot environment block for storing
  firmware and provisioning information. It has the following format:

    * CRC32 of bytes 4 through to the end
    * `"<key>=<value>\0"` for each key/value pair
    * `"\0"` an empty key/value pair to terminate the list.
      This looks like "\0\0" when you're viewing the file in a hex editor.
    * Filler bytes to the end of the environment block. These are usually `0xff`.

  The U-Boot environment configuration is loaded from /etc/fw_env.config.
  If you are using OTP >= 21, the contents of the U-Boot environment will be
  read directly from the device. This addresses an issue with parsing
  multi-line values from a call to `fw_printenv`.
  """
  use GenServer
  require Logger

  @config "/etc/fw_env.config"

  @doc """
  Start the KV store server
  """
  def start_link(kv \\ "") do
    GenServer.start_link(__MODULE__, kv, name: __MODULE__)
  end

  @doc """
  Get the key for only the active firmware slot
  """
  def get_active(key) do
    GenServer.call(__MODULE__, {:get_active, key})
  end

  @doc """
  Get the key regardless of firmware slot
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Get all key value pairs for only the active firmware slot
  """
  def get_all_active() do
    GenServer.call(__MODULE__, :get_all_active)
  end

  @doc """
  Get all keys regardless of firmware slot
  """
  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  # GenServer API

  def init(_kv) do
    with {:ok, config} <- read_config(@config),
         {dev_name, dev_offset, env_size} <- parse_config(config),
         {:ok, kv} <- load_kv(dev_name, dev_offset, env_size) do
      {:ok, kv}
    else
      _error ->
        exec = System.find_executable("fw_printenv")
        {:ok, load_kv(exec)}
    end
  end

  def handle_call({:get_active, key}, _from, s) do
    {:reply, active(key, s), s}
  end

  def handle_call({:get, key}, _from, s) do
    {:reply, Map.get(s, key), s}
  end

  def handle_call(:get_all_active, _from, s) do
    active = active(s) <> "."
    reply = filter_trim_active(s, active)
    {:reply, reply, s}
  end

  def handle_call(:get_all, _from, s) do
    {:reply, s, s}
  end

  def read_config(file) do
    case File.read(file) do
      {:ok, config} -> {:ok, config}
      _ -> {:error, :no_config}
    end
  end

  def parse_config(config) do
    [config] =
      config
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    [dev_name, dev_offset, env_size | _] = String.split(config) |> Enum.map(&String.trim/1)

    {dev_name, parse_int(dev_offset), parse_int(env_size)}
  end

  def parse_kv(kv) when is_list(kv) do
    kv
    |> Enum.map(&to_string(&1))
    |> Enum.map(&String.split(&1, "=", parts: 2))
    |> Enum.map(fn [k, v] -> {k, v} end)
    |> Enum.into(%{})
  end

  def parse_kv(kv) when is_binary(kv) do
    String.split(kv, "\n", trim: true)
    |> parse_kv()
  end

  defp load_kv(nil), do: %{}

  defp load_kv(exec) do
    case System.cmd(exec, []) do
      {result, 0} ->
        parse_kv(result)

      {result, code} ->
        Logger.warn("#{inspect(__MODULE__)} failed to load fw env (#{code}): #{result}")
        %{}
    end
  end

  # OTP 21 FTW
  # Load the UBoot env from the source
  def load_kv(dev_name, dev_offset, env_size) do
    case File.open(dev_name) do
      {:ok, fd} ->
        {:ok, bin} = :file.pread(fd, dev_offset, env_size)
        File.close(fd)
        <<expected_crc::little-size(32), tail::binary>> = bin
        actual_crc = :erlang.crc32(tail)

        if actual_crc == expected_crc do
          kv =
            tail
            |> :binary.bin_to_list()
            |> Enum.chunk_by(fn b -> b == 0 end)
            |> Enum.reject(&(&1 == [0]))
            |> Enum.take_while(&(hd(&1) != 0))
            |> parse_kv()

          {:ok, kv}
        else
          {:error, :invalid_crc}
        end

      error ->
        error
    end
  end

  defp active(s), do: Map.get(s, "nerves_fw_active", "")

  defp active(key, s) do
    Map.get(s, "#{active(s)}.#{key}")
  end

  defp filter_trim_active(s, active) do
    Enum.filter(s, fn {k, _} ->
      String.starts_with?(k, active)
    end)
    |> Enum.map(fn {k, v} -> {String.replace_leading(k, active, ""), v} end)
    |> Enum.into(%{})
  end

  defp parse_int(<<"0x", hex_int::binary()>>), do: String.to_integer(hex_int, 16)
  defp parse_int(decimal_int), do: String.to_integer(decimal_int)
end
