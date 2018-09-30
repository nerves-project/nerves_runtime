defmodule Nerves.Runtime.Device do
  require Logger
  @sysfs "/sys"

  @moduledoc """
  This is a utility module for triggering UEvents from the Linux kernel. You
  don't need to use it directly. See the README.md for receiving events when
  devices are added or removed from the system.
  """

  @doc """
  Send an "add" request to all devices to generate UEvents.
  """
  @spec discover() :: :ok
  def discover do
    "#{@sysfs}/devices"
    |> expand_uevent
    |> Enum.each(&invoke_uevent_action(&1, "add"))
  end

  defp expand_uevent(path) do
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
