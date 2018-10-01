defmodule Nerves.Runtime.Device do
  require Logger
  @sysfs "/sys"

  @moduledoc """
  This is a utility module for triggering UEvents from the Linux kernel. You
  don't need to use it directly. See the README.md for receiving events when
  devices are added or removed from the system.
  """

  @doc """
  Send an "add" request to all devices to generate uevents.
  """
  @spec discover() :: :ok
  def discover() do
    each_uevent("#{@sysfs}/devices", &invoke_uevent_action(&1, "add"))
  end

  defp each_uevent(dir, fun), do: each_uevent(dir, safe_ls(dir), fun)

  defp each_uevent(_dir, [], _fun), do: :ok

  defp each_uevent(dir, ["uevent" | rest], fun) do
    abs_path = Path.join(dir, "uevent")
    fun.(abs_path)
    each_uevent(dir, rest, fun)
  end

  defp each_uevent(dir, [filename | rest], fun) do
    abs_path = Path.join(dir, filename)

    if true_dir?(abs_path) do
      each_uevent(abs_path, safe_ls(abs_path), fun)
    end

    each_uevent(dir, rest, fun)
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
