defmodule Nerves.Runtime.Init do
  use GenServer
  alias Nerves.Runtime.KV

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

      opts = %{fstype: fstype, target: target, devpath: devpath}
      mounted_state = mounted_state(opts)
      Map.put(opts, :mounted_state, mounted_state)
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
    {mounts, 0} = System.cmd("mounts", [])
    mount =
      String.split(mounts, "\n")
      |> Enum.find(fn(mount) ->
        String.starts_with?(mount, "#{s.devpath} on #{s.target}")
      end)
    mounted_state =
      case mount do
        nil -> :unmounted
        mount ->
          IO.inspect mount
          opts =
            String.split(mount, " ")
            |> List.last
            |> String.slice(1..-2)
            |> String.split(",")
            |> IO.inspect
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
    System.cmd("mkfs.#{s.fs_type}", ["#{s.devpath}", "-F"])
    s
  end

  defp format_if_unmounted(s), do: s

  defp validate_mount(s), do: s.mounted

end
