defmodule Nerves.Runtime.Device do
  @moduledoc """
  This is a utility module for triggering UEvents from the Linux kernel. You
  don't need to use it directly. See the README.md for receiving events when
  devices are added or removed from the system.
  """

  @doc """
  Send an "add" request to all existing devices so that the UEvent handler
  can know about them.
  """
  @spec discover() :: :ok
  def discover() do
    "/sys/devices"
    |> find_all_uevent()
    |> Enum.each(&invoke_uevent_action(&1, "add"))
  end

  defp find_all_uevent(dir), do: find_all_uevent(dir, safe_ls(dir), [])

  defp find_all_uevent(_dir, [], acc), do: acc

  defp find_all_uevent(dir, ["uevent" | rest], acc) do
    abs_path = Path.join(dir, "uevent")
    find_all_uevent(dir, rest, [abs_path | acc])
  end

  defp find_all_uevent(dir, [filename | rest], acc) do
    abs_path = Path.join(dir, filename)

    next_acc =
      if true_dir?(abs_path) do
        find_all_uevent(abs_path, safe_ls(abs_path), acc)
      else
        acc
      end

    find_all_uevent(dir, rest, next_acc)
  end

  defp true_dir?(path) do
    # File.dir?/1 follows symlinks. true_dir?/1 does not.
    case File.lstat(path) do
      {:ok, stat} -> stat.type == :directory
      _ -> false
    end
  end

  defp safe_ls(path) do
    case File.ls(path) do
      {:ok, files} -> files
      _ -> []
    end
  end

  defp invoke_uevent_action(uevent, action) do
    File.write(uevent, action)
  end
end
