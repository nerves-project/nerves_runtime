defmodule Nerves.Runtime.UBootEnv.Config do
  @default_config_file "/etc/fw_env.config"

  @moduledoc """
  Utilities for reading the U-Boot tools `fw_env.config` file.
  """

  @doc """
  Read and decode the specified file (or `fw_env.config` if not passed).

  On success, this returns a tuple with the device name that contains the
  U-Boot environment block, the offset in that file, and the environment size.
  """
  @spec read(Path.t()) ::
          {:ok,
           {dev_name :: String.t(), dev_offset :: non_neg_integer(), env_size :: pos_integer()}}
          | {:error, reason :: any}
  def read(config_file \\ @default_config_file) do
    case File.read(config_file) do
      {:ok, config} -> {:ok, decode(config)}
      _error -> {:error, :no_config}
    end
  end

  @doc """
  Decode the contents of a `fw_env.config` file.
  """
  @spec decode(String.t()) ::
          {dev_name :: String.t(), dev_offset :: non_neg_integer(), env_size :: pos_integer()}
  def decode(config) do
    [config] =
      config
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&String.starts_with?(&1, "#"))

    [dev_name, dev_offset, env_size | _] = String.split(config) |> Enum.map(&String.trim/1)

    {dev_name, parse_int(dev_offset), parse_int(env_size)}
  end

  defp parse_int(<<"0x", hex_int::binary()>>), do: String.to_integer(hex_int, 16)
  defp parse_int(decimal_int), do: String.to_integer(decimal_int)
end
