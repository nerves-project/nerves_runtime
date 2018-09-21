defmodule Nerves.Runtime.KV.UBootEnv do
  @moduledoc """
  ## Technical Information

  Nerves.Runtime.KV.UBootEnv uses a non-replicated U-Boot environment block for
  storing firmware and provisioning information. It has the following format:

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

  require Logger

  @behaviour Nerves.Runtime.KV

  @config "/etc/fw_env.config"

  def init(_opts) do
    read()
  end

  def put(key, value) do
    read()
    |> Map.put(key, value)
    |> write()
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

  def decode(kv) when is_list(kv) do
    kv
    |> Enum.map(&to_string(&1))
    |> Enum.map(&String.split(&1, "=", parts: 2))
    |> Enum.map(fn [k, v] -> {k, v} end)
    |> Enum.into(%{})
  end

  def decode(kv) when is_binary(kv) do
    String.split(kv, "\n", trim: true)
    |> decode()
  end

  def encode(kv, env_size) when is_map(kv) do
    kv =
      kv
      |> Enum.map(&(elem(&1, 0) <> "=" <> elem(&1, 1)))
      |> Enum.join(<<0>>)

    kv = kv <> <<0, 0>>
    padding = env_size - byte_size(kv) - 4
    padding = <<-1::signed-unit(8)-size(padding)>>
    crc = :erlang.crc32(kv <> padding)
    crc = <<crc::little-size(32)>>
    crc <> kv <> padding
  end

  def read() do
    with {:ok, config} <- read_config(@config),
         {dev_name, dev_offset, env_size} <- parse_config(config),
         {:ok, kv} <- load(dev_name, dev_offset, env_size) do
      kv
    else
      _error ->
        exec = System.find_executable("fw_printenv")
        load(exec)
    end
  end

  def write(kv) do
    with {:ok, config} <- read_config(@config),
         {dev_name, dev_offset, env_size} <- parse_config(config),
         {:ok, fd} <- File.open(dev_name, [:raw, :binary, :write]) do
      uboot_env = encode(kv, env_size)
      :ok = :file.pwrite(fd, dev_offset, uboot_env)
      File.close(fd)
    else
      _error ->
        exec = System.find_executable("fw_setenv")

        Enum.each(kv, fn {k, v} ->
          System.cmd(exec, [k, v])
        end)
    end
  end

  def load(nil), do: %{}

  def load(exec) do
    case System.cmd(exec, []) do
      {result, 0} ->
        decode(result)

      {result, code} ->
        Logger.warn("#{inspect(__MODULE__)} failed to load fw env (#{code}): #{result}")
        %{}
    end
  end

  # OTP 21 FTW
  # Load the UBoot env from the source
  def load(dev_name, dev_offset, env_size) do
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
            |> decode()

          {:ok, kv}
        else
          {:error, :invalid_crc}
        end

      error ->
        error
    end
  end

  defp parse_int(<<"0x", hex_int::binary()>>), do: String.to_integer(hex_int, 16)
  defp parse_int(decimal_int), do: String.to_integer(decimal_int)
end
