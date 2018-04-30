defmodule Nerves.Runtime.ConfigFS do
  use GenServer
  alias Nerves.Runtime
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    # configfs_home="/sys/kernel/config"
    # mount none $configfs_home -t configfs
    case Runtime.cmd("mount", [], :return) do
      {str, 0} -> String.contains?(str, "none on /sys/kernel/config type configfs")
      {err, _} -> raise "Failed to check mounted partitions: #{inspect(err)}"
    end
    |> unless do
      Logger.info("Going to mount ConfigFS.")
      {_, 0} = Runtime.cmd("mount", ["none", "/sys/kernel/config", "-t", "configfs"], :return)
    end

    apply_map_to_configfs(gadget_config())
    g = "/sys/kernel/config/usb_gadget/g"
    apply_link(Path.join(g, "functions/ecm.usb0"), Path.join(g, "configs/c.1"))
    apply_link(Path.join(g, "functions/acm.usb0"), Path.join(g, "configs/c.1"))
    apply_link(Path.join(g, "functions/rndis.usb0"), Path.join(g, "configs/c.2"))
    apply_link(Path.join(g, "functions/acm.usb0"), Path.join(g, "configs/c.2"))
    # apply_link(Path.join(g, "configs/c.2"), Path.join(g, "configs/os_desc"))
    [device] = File.ls!("/sys/class/udc")

    write(Path.join(g, "UDC"), device)
    {_, 0} = Runtime.cmd("sh", ["-c", "ls /sys/class/udc > #{Path.join(g, "UDC")}"], :return)

    {:ok, %{}}
  end

  def apply_map_to_configfs(map) do
    mani = build_manifest(map)

    Enum.each(Enum.reverse(mani.folders), fn folder ->
      mkdir_p(Path.join("/sys/kernel/config/", folder))
    end)

    Enum.each(Enum.reverse(mani.files), fn {file, value} ->
      write(Path.join("/sys/kernel/config/", file), value)
    end)
  end

  defp apply_link(patha, pathb) do
    ln_s(patha, pathb)
  end

  defp mkdir_p(dir) do
    {_, 0} = Runtime.cmd("mkdir", ["-p", dir], :return)
  end

  defp ln_s(patha, pathb) do
    {_, 0} = Runtime.cmd("ln", ["-s", patha, pathb], :return)
  end

  defp write(path, value) do
    {_, 0} = Runtime.cmd("sh", ["-c", "echo", value, ">", path], :return)
  end

  def build_manifest(map, state \\ %{path: "/", files: [], folders: []})

  def build_manifest(%{} = map, state) do
    build_manifest(Map.to_list(map), state)
  end

  def build_manifest([{key, %{} = val} | rest], state) when map_size(val) == 0 do
    folder = Path.join(state.path, key)
    build_manifest(rest, %{state | path: state.path, folders: (state.folders -- [folder]) ++ [folder]})
  end

  def build_manifest([{key, %{} = val} | rest], state) do
    state = build_manifest(val, %{state | path: Path.join(state.path, key)})
    build_manifest(rest, state)
  end

  def build_manifest([{key, edge_node} | rest], state) do
    build_manifest(rest, %{
      state
      | folders: (state.folders -- [state.path]) ++ [state.path],
        files: state.files ++ [{Path.join(state.path, key), edge_node}]
    })
  end

  def build_manifest([], state), do: %{state | path: Path.dirname(state.path)}

  def gadget_config do
    %{
      "usb_gadget" => %{
        "g" => %{
          "bcdUSB" => "0x0200",
          "bcdDevice" => "0x3000",
          "bDeviceClass" => "2",
          "idVendor" => "0x1d6b",
          "idProduct" => "0x0104",
          "os_desc" => %{
            "use" => "1",
            "b_vendor_code" => "0xcd",
            "qw_sign" => "MSFT100"
          },
          "functions" => %{
            "ecm.usb0" => %{
              "dev_addr" => "02:1e:58:8a:8f:42",
              "host_addr" => "12:1e:58:8a:8f:42"
            },
            "mass_storage.0" => %{
              "stall" => "1",
              "lun.0" => %{
                "file" => "whatever",
                "removable" => "1",
                "cdrom" => "0"
              }
            },
            "acm.usb0" => %{},
            "rndis.usb0" => %{
              "dev_addr" => "22:1e:58:8a:8f:42",
              "host_addr" => "32:1e:58:8a:8f:42",
              "os_desc" => %{
                "interface.rndis" => %{
                  "compatible_id" => "RNDIS",
                  "sub_compatible_id" => "5162001"
                }
              }
            }
          },
          "strings" => %{
            "0x409" => %{
              "manufacturer" => "Nerves Team",
              "product" => "Nerves OTG Device",
              "serialnumber" => "abcdefg123456"
            }
          },
          "configs" => %{
            "c.1" => %{
              "bmAttributes" => "0xC0",
              "MaxPower" => "1",
              "strings" => %{
                "0x409" => %{
                  "configuration" => "CDC"
                }
              }
            },
            "c.2" => %{
              "bmAttributes" => "0xC0",
              "MaxPower" => "1",
              "strings" => %{
                "0x409" => %{
                  "configuration" => "RNDIS"
                }
              }
            }
          }
        }
      }
    }
  end
end
