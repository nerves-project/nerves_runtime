defmodule Nerves.Runtime.Helpers do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      IO.puts(
        "The Nerves.Runtime.Helpers have been removed. Use https://hex.pm/packages/toolshed instead."
      )
    end
  end
end
