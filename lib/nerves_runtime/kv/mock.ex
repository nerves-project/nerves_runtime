defmodule Nerves.Runtime.KV.Mock do
  @behaviour Nerves.Runtime.KV

  def init(state) do
    Application.get_env(:nerves_runtime, __MODULE__) || init_state(state)
  end

  def init_state(state) when is_map(state), do: state
  def init_state(_state), do: %{}
end
