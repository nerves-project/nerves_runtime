defmodule Nerves.Runtime.UBootEnv do
  @moduledoc """
  Nerves.Runtime.UBootEnv reads a non-replicated U-Boot environment block for
  storing firmware and provisioning information.

  The U-Boot environment format looks like this:

    * CRC32 of bytes 4 through to the end
    * `"<key>=<value>\0"` for each key/value pair
    * `"\0"` an empty key/value pair to terminate the list.
      This looks like "\0\0" when you're viewing the file in a hex editor.
    * Filler bytes to the end of the environment block. These are usually `0xff`.

  The U-Boot environment configuration is loaded from /etc/fw_env.config.
  If you are using OTP >= 21, the contents of the U-Boot environment will be
  read directly from the device. If not, the code falls back to `fw_printenv`,
  but be aware that there's a known issue with values that have embedded
  newlines.
  """

  alias Nerves.Runtime.UBootEnv.{Config, Tools}

  @doc """
  Read the UBoot environment into a map or key value pairs
  """
  @spec read() ::
          {:ok, map}
          | {:error, reason :: binary}
  def read() do
    with {:ok, {dev_name, dev_offset, env_size}} <- Config.read(),
         {:ok, kv} <- load(dev_name, dev_offset, env_size) do
      {:ok, kv}
    else
      _error ->
        Tools.fw_printenv()
    end
  end

  @doc """
  Write a map of key value pairs to the UBoot environment
  """
  @spec write(kv :: map) :: :ok | {:error, reason :: any}
  def write(kv) do
    with {:ok, {dev_name, dev_offset, env_size}} <- Config.read(),
         {:ok, fd} <- File.open(dev_name, [:raw, :binary, :write]) do
      uboot_env = encode(kv, env_size)
      :ok = :file.pwrite(fd, dev_offset, uboot_env)
      File.close(fd)
    else
      _error ->
        Enum.each(kv, fn {key, value} ->
          Tools.fw_setenv(key, value)
        end)
    end
  end

  @doc """
  Decode a list of key value pairs into a map
  """
  @spec decode([String.t()]) :: map()
  def decode(env) when is_list(env) do
    env
    |> Enum.map(&to_string(&1))
    |> Enum.map(&String.split(&1, "=", parts: 2))
    |> Enum.map(fn [k, v] -> {k, v} end)
    |> Enum.into(%{})
  end

  @doc """
  Encode a list of key value pairs into the binary form of the UBoot Env
  """
  @spec encode(map(), pos_integer()) :: binary()
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

  # Requires OTP >= 21
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
end
