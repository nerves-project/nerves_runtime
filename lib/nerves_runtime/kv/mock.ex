defmodule Nerves.Runtime.KV.Mock do
  @behaviour Nerves.Runtime.KV

  @moduledoc """
  Applications that depend on `nerves_runtime` for accessing provisioning
  information from the `Nerves.Runtime.KV` can mock the contents through the
  Application config.

  ```elixir
  config :nerves_runtime, :modules, [
    {Nerves.Runtime.KV.Mock, %{"key" => "value"}}
  ]
  ```
  """
  def init(state) do
    Application.get_env(:nerves_runtime, __MODULE__) || init_state(state)
  end

  def init_state(state) when is_map(state), do: state
  def init_state(_state), do: %{}
end
