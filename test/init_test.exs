defmodule InitTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Init

  alias Nerves.Runtime.Init

  # test "mounted?" do
  #   mounts =
  #     """
  #     sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
  #     proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
  #     udev on /dev type devtmpfs (rw,nosuid,relatime,size=1979780k,nr_inodes=494945,mode=755)
  #     devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000)
  #     tmpfs on /run type tmpfs (ro,nosuid,noexec,relatime,size=400008k,mode=755)
  #     /dev/sda1 on / type ext4 (rw,relatime,errors=remount-ro,data=ordered)
  #     """
  #   assert Init.mounted_state("/dev/sda1", "/", mounts) == :mounted
  #   assert Init.mounted_state("tmpfs", "/run", mounts) == :mounted_with_error
  #   assert Init.mounted_state("dsfds", "fggvef", mounts) == :unmounted
  # end
end
