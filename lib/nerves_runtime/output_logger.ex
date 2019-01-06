defmodule Nerves.Runtime.OutputLogger do
  defstruct [:level]
  @type t :: %__MODULE__{level: Logger.level()}

  @moduledoc false

  @spec new(Logger.level()) :: t()
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
          |> String.split("\n", trim: true)
          |> Enum.each(&Logger.bare_log(level, fn -> &1 end))

        :ok, _ ->
          stream
      end
    end
  end
end
