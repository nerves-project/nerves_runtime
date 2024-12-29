defmodule Nerves.Runtime.KVBackend.UBootEnv do
  @moduledoc """
  U-Boot environment block KV store

  This is the default KV store. It delegates to the `UBootEnv` library
  for loading and saving to a U-Boot formatted environment block. There's
  nothing to configure. It will find the block by reading `/etc/fw_env.config`.
  """

  @behaviour Nerves.Runtime.KVBackend

  @impl Nerves.Runtime.KVBackend
  def load(options) do
    with {:ok, config} <- options_to_uboot_config(options) do
      UBootEnv.read(config)
    end
  end

  @impl Nerves.Runtime.KVBackend
  def save(%{} = kv, options) do
    with {:ok, config} <- options_to_uboot_config(options),
         {:ok, current_kv} <- UBootEnv.read(config) do
      merged_kv = Map.merge(current_kv, kv)
      UBootEnv.write(merged_kv, config)
    end
  end

  defp options_to_uboot_config(options) do
    case Keyword.fetch(options, :uboot_locations) do
      {:ok, locations} ->
        {:ok, %UBootEnv.Config{locations: Enum.map(locations, &struct(UBootEnv.Location, &1))}}

      :error ->
        UBootEnv.configuration()
    end
  end
end
