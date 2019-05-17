defmodule Nerves.Runtime.KV.UBootEnv do
  @behaviour Nerves.Runtime.KV

  @moduledoc false

  def init(_opts) do
    case UBootEnv.read() do
      {:ok, kv} -> kv
      _error -> %{}
    end
  end

  def put(key, value) do
    put(%{key => value})
  end

  def put(%{} = kv) do
    case UBootEnv.read() do
      {:ok, current_kv} ->
        current_kv
        |> Map.merge(kv)
        |> UBootEnv.write()

      error ->
        error
    end
  end
end
