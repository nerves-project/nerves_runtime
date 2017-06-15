defmodule Nerves.Runtime.Init do
  use GenServer
  alias Nerves.Runtime.KV

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init([]) do
    init_application_partition()
    {:ok, %{}}
  end

  def init_application_partition do
    prefix = "nerves_fw_application_part0"
    fstype = KV.get("#{prefix}_fstype")
    target = KV.get("#{prefix}_target")
    devpath = KV.get("#{prefix}_devpath")
    if  fstype  != nil
    and target  != nil
    and devpath != nil do
 #      System.cmd("mount", ["-t", fstype, "-o", "rw",
 # +      unquote(block_device), state_path])
    end
  end
end
