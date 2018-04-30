defmodule Nerves.Runtime.ConfigFS do
  use GenServer
  alias Nerves.Runtime


  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    Runtime.cmd("mount", ["none", "/sys/kernel/config", "-t", "configfs"], :info)

    apply_map_to_configfs(gadget_config())
    g = "/sys/kernel/config/usb_gadget/g"
    apply_link(Path.join(g, "functions/ecm.usb0"), Path.join(g, "configs/c.1"))
    apply_link(Path.join(g, "functions/acm.usb0"), Path.join(g, "configs/c.1"))
    apply_link(Path.join(g, "functions/rndis.usb0"), Path.join(g, "configs/c.2"))
    apply_link(Path.join(g, "functions/acm.usb0"), Path.join(g, "configs/c.2"))
    apply_link(Path.join(g, "configs/c.2"), Path.join(g, "configs/os_desc"))
    device = File.ls!("/sys/class/udc") |> List.first()
    write(Path.join(g, "UDC"), device)
    {:ok, %{}}
  end

  def apply_map_to_configfs(map) do
    mani = build_manifest(map)
    Enum.each(mani.folders, fn(folder) ->
      # IO.puts "mkdir -p /sys/kernel/config/#{folder}"
      mkdir_p(Path.join("/sys/kernel/config/", folder))
    end)
    Enum.each(mani.files, fn({file, value}) ->
      # IO.puts "echo '#{value}' > /sys/kernel/config/#{file}"
      write(Path.join("/sys/kernel/config/", file), value)
    end)
  end

  defp apply_link(patha, pathb) do
    # IO.puts "ln -s #{patha} #{pathb}"
    ln_s(patha, pathb)
  end

  defp mkdir_p(dir) do
    System.cmd("mkdir", ["-p", dir])
  end

  defp ln_s(patha, pathb) do
    System.cmd("ln", ["-s", patha, pathb])
  end

  defp write(path, value) do
    System.cmd("sh", ["-c", "echo", value, ">", path])
  end

  defp build_manifest(map, state \\ %{path: "", files: [], folders: []})
  defp build_manifest(%{} = map, state) do
    build_manifest(Map.to_list(map), state)
  end

  defp build_manifest([{key, %{} = val} | rest], state) do
    state = build_manifest(val, %{state | path: Path.join(state.path, key)})
    build_manifest(rest, %{state | path: state.path})
  end

  defp build_manifest([{key, edge_node} | rest], state) do
    build_manifest(rest, %{state | folders: (state.folders -- [state.path]) ++ [state.path], files: state.files ++ [{Path.join(state.path, key), edge_node}]})
  end

  defp build_manifest([], state), do: state


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
