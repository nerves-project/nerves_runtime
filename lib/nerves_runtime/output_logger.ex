defmodule Nerves.Runtime.OutputLogger do
  @moduledoc false
  defstruct [:level]
  @type t :: %__MODULE__{level: Logger.level()}

  @spec new(Logger.level()) :: t()
  def new(level) do
    %__MODULE__{level: level}
  end

  defimpl Collectable do
    @spec into(Nerves.Runtime.OutputLogger.t()) ::
            {nil,
             (nil, :done | :halt | {:cont, binary} ->
                nil | Nerves.Runtime.OutputLogger.t())}
    def into(%{level: level} = stream) do
      {nil, log_fn(stream, level)}
    end

    defp log_fn(stream, level) do
      fn
        nil, {:cont, logs} ->
          logs
          |> String.split("\n")
          |> Enum.each(&Logger.bare_log(level, fn -> String.trim(&1) end))

          nil

        nil, :halt ->
          nil

        nil, :done ->
          stream
      end
    end
  end
end
