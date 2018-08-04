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
    apply_link(Path.join(g, "functions/rndis.usb0"), Path.join(g, "configs/c.1/rndis.usb0"))
    apply_link(Path.join(g, "functions/ecm.usb1"), Path.join(g, "configs/c.1/ecm.usb1"))
    apply_link(Path.join(g, "functions/acm.GS0"), Path.join(g, "configs/c.1/acm.GS0"))
    apply_link(Path.join(g, "configs/c.1"), Path.join(g, "os_desc/c.1"))

    {_, 0} = Runtime.cmd("sh", ["-c", "ls /sys/class/udc > #{Path.join(g, "UDC")}"], :return)

    :os.cmd('ip link set bond0 down')
    :os.cmd('echo active-backup > /sys/class/net/bond0/bonding/mode')
    :os.cmd('echo 100 > /sys/class/net/bond0/bonding/miimon')
    :os.cmd('echo +usb0 > /sys/class/net/bond0/bonding/slaves')
    :os.cmd('echo +usb1 > /sys/class/net/bond0/bonding/slaves')
    :os.cmd('echo usb1 > /sys/class/net/bond0/bonding/primary')
    :os.cmd('ip link set bond0 up')

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
    Logger.info("Creating #{dir}")
    File.mkdir_p!(dir)
  end

  defp ln_s(patha, pathb) do
    Logger.info("Linking #{pathb} to #{patha}")
    #{_, 0} = Runtime.cmd("ln", ["-s", patha, pathb], :return)
    File.ln_s!(patha, pathb)
  end

  defp write(path, value) do
    Logger.info("Writing #{value} to #{path}")
    File.write!(path, value)
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
          "bcdDevice" => "0x0100",
          "bDeviceClass" => "0xEF",
          "bDeviceSubClass" => "0x02",
          "bDeviceProtocol" => "0x01",
          "idVendor" => "0x0525",
          "idProduct" => "0xB4AB",
          "os_desc" => %{
            "use" => "1",
            "b_vendor_code" => "0xcd",
            "qw_sign" => "MSFT100"
          },
          "functions" => %{
            "rndis.usb0" => %{
              "dev_addr" => "22:1e:58:8a:8f:42",
              "host_addr" => "32:1e:58:8a:8f:42",
              "os_desc" => %{
                "interface.rndis" => %{
                  "compatible_id" => "RNDIS",
                  "sub_compatible_id" => "5162001"
                }
              }
            },
            "ecm.usb1" => %{
              "dev_addr" => "02:1e:58:8a:8f:42",
              "host_addr" => "12:1e:58:8a:8f:42"
            },
            "acm.GS0" => %{},
          },
          "strings" => %{
            "0x409" => %{
              "manufacturer" => Nerves.Runtime.KV.get_active("nerves_fw_author"),
              "product" => Nerves.Runtime.KV.get_active("nerves_fw_product"),
              # This is obviously not a good idea.
              "serialnumber" => Nerves.Runtime.cmd("cat", ["/proc/cpuinfo"], :return) |> elem(0) |> String.split("Serial\t\t: ") |> List.last() |> String.trim()
            }
          },
          "configs" => %{
            "c.1" => %{
              "bmAttributes" => "0xC0",
              "MaxPower" => "1",
              "strings" => %{
                "0x409" => %{
                  "configuration" => "Config 1"
                }
              }
            }
          }
        }
      }
    }
  end
end
