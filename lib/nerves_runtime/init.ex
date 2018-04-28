defmodule Nerves.Runtime.Init do
  use GenServer
  require Logger
  alias Nerves.Runtime
  alias Nerves.Runtime.KV

  # Use a fixed UUID for the application partition. This has two
  # purposes:
  #
  #   1. mkfs.ext4 calls generate_uuid which calls getrandom(). That
  #      call can block indefinitely until the urandom pool has been
  #      initialized. This will delay startup for a long time if the
  #      app partition needs to be reformated. (mkfs.ext4 has two calls
  #      to getrandom() so this only fixes one of them.)
  #   2. Applications that would prefer to look up a partition by UUID
  #      can do so.
  @app_partition_uuid "3041e38d-615b-48d4-affb-a7787b5c4c39"

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    init_application_partition()
    {:ok, %{}}
  end

  def init_application_partition() do
    prefix = "nerves_fw_application_part0"
    fstype = KV.get_active("#{prefix}_fstype")
    target = KV.get_active("#{prefix}_target")
    devpath = KV.get_active("#{prefix}_devpath")

    %{mounted: nil, fstype: fstype, target: target, devpath: devpath}
    |> do_format()
  end

  defp do_format(%{fstype: nil}), do: :noop
  defp do_format(%{target: nil}), do: :noop
  defp do_format(%{devpath: nil}), do: :noop

  defp do_format(s) do
    s
    |> mounted_state()
    |> unmount_if_error()
    |> mount()
    |> unmount_if_error()
    |> format_if_unmounted()
    |> mount()
    |> validate_mount()
  end

  def mounted_state(s) do
    {mounts, 0} = Runtime.cmd("mount", [], :return)

    mount =
      String.split(mounts, "\n")
      |> Enum.find(fn mount ->
        String.starts_with?(mount, "#{s.devpath} on #{s.target}")
      end)

    mounted_state =
      case mount do
        nil ->
          :unmounted

        mount ->
          opts =
            mount
            |> String.split(" ")
            |> List.last()
            |> String.slice(1..-2)
            |> String.split(",")

          cond do
            "rw" in opts ->
              :mounted

            true ->
              # Mount was read only or any other type
              :mounted_with_error
          end
      end

    %{s | mounted: mounted_state}
  end

  defp mount(%{mounted: :mounted} = s), do: s

  defp mount(s) do
    Runtime.cmd("mount", ["-t", s.fstype, "-o", "rw", s.devpath, s.target], :info)
    mounted_state(s)
  end

  defp unmount_if_error(%{mounted: :mounted_with_error} = s) do
    Runtime.cmd("umount", [s.target], :info)
    mounted_state(s)
  end

  defp unmount_if_error(s), do: s

  defp format_if_unmounted(%{mounted: :unmounted, fstype: fstype, devpath: devpath} = s) do
    "Formatting application partition. If this hangs, it could be waiting on the urandom pool to be initialized"
    |> Logger.warn()

    mkfs(fstype, devpath)
    s
  end

  defp format_if_unmounted(s), do: s

  defp mkfs("f2fs", devpath) do
    Runtime.cmd("mkfs.f2fs", ["#{devpath}"], :info)
  end

  defp mkfs(fstype, devpath) do
    Runtime.cmd("mkfs.#{fstype}", ["-U", @app_partition_uuid, "-F", "#{devpath}"], :info)
  end

  defp validate_mount(s), do: s.mounted
end
