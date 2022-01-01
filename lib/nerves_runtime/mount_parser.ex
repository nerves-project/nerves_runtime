defmodule Nerves.Runtime.MountParser do
  @moduledoc false

  @typedoc false
  @type mounts() :: %{String.t() => %{device: String.t(), type: String.t(), flags: [String.t()]}}

  @doc false
  @spec parse(String.t()) :: mounts()
  def parse(mount_output) do
    mount_output
    |> String.split("\n")
    |> Enum.reduce(%{}, &parse_line/2)
  end

  defp parse_line(line, mounts) do
    case String.split(line) do
      [device, "on", target, "type", type, flags_text | _] ->
        flags = parse_flags(flags_text)
        Map.put(mounts, target, %{device: device, type: type, flags: flags})

      _ ->
        # Ignore unknown mount strings
        mounts
    end
  end

  defp parse_flags(flags_text) do
    flags_text
    |> String.trim_leading("(")
    |> String.trim_trailing(")")
    |> String.split(",")
  end
end
