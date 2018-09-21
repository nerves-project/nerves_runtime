defmodule Nerves.Runtime.UBootEnv.Config do
  @default_config_file "/etc/fw_env.config"

  @spec read(file :: binary) ::
          {:ok, {dev_name :: binary, dev_offset :: non_neg_integer, env_size :: non_neg_integer}}
          | {:error, reason :: any}
  def read(config_file \\ nil) do
    config_file = config_file || @default_config_file

    case File.read(config_file) do
      {:ok, config} -> {:ok, decode(config)}
      _error -> {:error, :no_config}
    end
  end

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
