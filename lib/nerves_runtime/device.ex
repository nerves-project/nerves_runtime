defmodule Nerves.Runtime.Device do
  require Logger
  @sysfs "/sys"

  def discover do
    "#{@sysfs}/devices"
    |> expand_uevent
    |> Enum.each(&invoke_uevent_action(&1, "add"))
  end

  def expand_uevent(path) do
    path
    |> Path.expand()
    |> File.ls!()
    |> Enum.map(&Path.join(path, &1))
    |> Enum.reduce([], fn path, acc ->
      filetype =
        case File.lstat(path) do
          {:ok, stat} -> stat.type
          _ -> :error
        end

      basename = Path.basename(path)

      cond do
        basename == "uevent" ->
          [path | acc]

        filetype == :directory ->
          [expand_uevent(path) | acc]

        true ->
          acc
      end
    end)
    |> List.flatten()
  end

  defp invoke_uevent_action(uevent, action) do
    File.write(uevent, action)
  end
end
