defmodule Nerves.Runtime.KVBackend.UBootEnv do
  @moduledoc """
  U-Boot environment block KV store

  This is the default KV store. It delegates to the `UBootEnv` library
  for loading and saving to a U-Boot formatted environment block. There's
  nothing to configure. It will find the block by reading `/etc/fw_env.config`.
  """

  @behaviour Nerves.Runtime.KVBackend

  @impl Nerves.Runtime.KVBackend
  def load(_options) do
    UBootEnv.read()
  end

  @impl Nerves.Runtime.KVBackend
  def save(%{} = kv, _options) do
    with {:ok, current_kv} <- UBootEnv.read() do
      merged_kv = Map.merge(current_kv, kv)
      UBootEnv.write(merged_kv)
    end
  end
end
