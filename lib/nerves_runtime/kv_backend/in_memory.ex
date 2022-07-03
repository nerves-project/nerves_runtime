defmodule Nerves.Runtime.KVBackend.InMemory do
  @moduledoc """
  In-memory KV store

  This KV store keeps everything in memory. Use it by specifying it
  as a backend in the application configuration. Specifying an initial
  set of contents is optional.

  ```elixir
  config :nerves_runtime, :kv_backend, {Nerves.Runtime.KV.InMemory, contents: %{"key" => "value"}}
  ```
  """
  @behaviour Nerves.Runtime.KVBackend

  @impl Nerves.Runtime.KVBackend
  def load(options) do
    case Keyword.fetch(options, :contents) do
      {:ok, contents} when is_map(contents) -> {:ok, contents}
      _ -> {:ok, %{}}
    end
  end

  @impl Nerves.Runtime.KVBackend
  def save(_new_state, _options), do: :ok
end
