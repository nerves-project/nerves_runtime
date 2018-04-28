defmodule Nerves.Runtime.OutputLogger do
  defstruct [:level]

  def new(level) do
    %__MODULE__{level: level}
  end

  defimpl Collectable do
    def into(%{level: level} = stream) do
      {:ok, log(stream, level)}
    end

    def log(stream, level) do
      fn
        :ok, {:cont, logs} ->
          logs
          |> String.split("\n")
          |> Enum.each(&Logger.bare_log(level, fn -> &1 end))

        :ok, _ ->
          stream
      end
    end
  end
end
