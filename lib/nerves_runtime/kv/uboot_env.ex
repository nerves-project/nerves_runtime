defmodule Nerves.Runtime.KV.UBootEnv do
  @behaviour Nerves.Runtime.KV

  @moduledoc false

  @impl Nerves.Runtime.KV
  def init(_opts) do
    case UBootEnv.read() do
      {:ok, kv} -> kv
      _error -> %{}
    end
  end

  @impl Nerves.Runtime.KV
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
