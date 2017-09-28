defmodule Nerves.Runtime.Init do
  use GenServer
  require Logger
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
    if  fstype  != nil
    and target  != nil
    and devpath != nil do

      opts = %{mounted: nil, fstype: fstype, target: target, devpath: devpath}
      mounted_state(opts)
      |> unmount_if_error()
      |> mount()
      |> unmount_if_error()
      |> format_if_unmounted()
      |> mount()
      |> validate_mount()
    else
      :noop
    end
  end

  def mounted_state(s) do
    {mounts, 0} = System.cmd("mount", [])
    mount =
      String.split(mounts, "\n")
      |> Enum.find(fn(mount) ->
        String.starts_with?(mount, "#{s.devpath} on #{s.target}")
      end)
    mounted_state =
      case mount do
        nil -> :unmounted
        mount ->
          opts =
            String.split(mount, " ")
            |> List.last
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
    System.cmd("mount", ["-t", s.fstype, "-o", "rw", s.devpath, s.target])
    mounted_state(s)
  end

  defp unmount_if_error(%{mounted: :mounted_with_error} = s) do
    System.cmd("umount", [s.target])
    mounted_state(s)
  end
  defp unmount_if_error(s), do: s

  defp format_if_unmounted(%{mounted: :unmounted} = s) do
    Logger.warn("Formatting application partition. If this hangs, it could be waiting on the urandom pool to be initialized")
    System.cmd("mkfs.#{s.fstype}", ["-U", @app_partition_uuid, "-F", "#{s.devpath}"])
    s
  end

  defp format_if_unmounted(s), do: s

  defp validate_mount(s), do: s.mounted

end
