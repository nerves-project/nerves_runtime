defmodule Nerves.Runtime.KV.UBootEnv do
  @behaviour Nerves.Runtime.KV

  @moduledoc false

  alias Nerves.Runtime.UBootEnv

  def init(_opts) do
    case UBootEnv.read() do
      {:ok, kv} -> kv
      _error -> %{}
    end
  end

  def put(key, value) do
    case UBootEnv.read() do
      {:ok, kv} ->
        kv
        |> Map.put(key, value)
        |> UBootEnv.write()

      error ->
        error
    end
  end
end
