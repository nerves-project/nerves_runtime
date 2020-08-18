defmodule Nerves.Runtime.KV.Mock do
  @behaviour Nerves.Runtime.KV

  @moduledoc """
  Applications that depend on `nerves_runtime` for accessing provisioning
  information from the `Nerves.Runtime.KV` can mock the contents through the
  Application config.

  ```elixir
  config :nerves_runtime, Nerves.Runtime.KV.Mock, %{"key" => "value"}
  ```
  """
  @impl Nerves.Runtime.KV
  def init(state) do
    Application.get_env(:nerves_runtime, __MODULE__) || init_state(state)
  end

  defp init_state(state) when is_map(state), do: state
  defp init_state(_state), do: %{}

  @impl Nerves.Runtime.KV
  def put(_new_state), do: :ok
end
