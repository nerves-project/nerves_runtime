defmodule T do
  def expand do
     Nerves.Runtime.Device.expand_path "/sys/devices"
  end

  def reload do
    r Nerves.Runtime.Device
  end
end
