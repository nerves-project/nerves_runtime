# SPDX-FileCopyrightText: 2022 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.MountParserTest do
  use ExUnit.Case

  alias Nerves.Runtime.MountParser

  test "parses example mount output" do
    mount_output = """
    /dev/root on / type squashfs (ro,relatime)
    devtmpfs on /dev type devtmpfs (rw,nosuid,noexec,relatime,size=1024k,nr_inodes=57380,mode=755)
    proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)
    sysfs on /sys type sysfs (rw,nosuid,nodev,noexec,relatime)
    devpts on /dev/pts type devpts (rw,nosuid,noexec,relatime,gid=5,mode=620,ptmxmode=000)
    tmpfs on /tmp type tmpfs (rw,nosuid,nodev,noexec,relatime,size=50924k)
    tmpfs on /run type tmpfs (rw,nosuid,nodev,noexec,relatime,size=25464k,mode=755)
    /dev/mmcblk0p1 on /mnt/boot type vfat (ro,nosuid,nodev,noexec,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
    /dev/mmcblk0p4 on /root type f2fs (rw,lazytime,nodev,relatime,background_gc=on,discard,no_heap,inline_data,inline_dentry,flush_merge,extent_cache,mode=adaptive,active_logs=6,alloc_mode=reuse,fsync_mode=posix)
    tmpfs on /sys/fs/cgroup type tmpfs (rw,nosuid,nodev,noexec,relatime,size=1024k,mode=755)
    cpu on /sys/fs/cgroup/cpu type cgroup (rw,nosuid,nodev,noexec,relatime,cpu)
    memory on /sys/fs/cgroup/memory type cgroup (rw,nosuid,nodev,noexec,relatime,memory)
    pstore on /sys/fs/pstore type pstore (rw,nosuid,nodev,noexec,relatime)
    """

    expected = %{
      "/" => %{device: "/dev/root", type: "squashfs", flags: ["ro", "relatime"]},
      "/dev" => %{
        device: "devtmpfs",
        type: "devtmpfs",
        flags: ["rw", "nosuid", "noexec", "relatime", "size=1024k", "nr_inodes=57380", "mode=755"]
      },
      "/proc" => %{
        device: "proc",
        type: "proc",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime"]
      },
      "/sys" => %{
        device: "sysfs",
        type: "sysfs",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime"]
      },
      "/dev/pts" => %{
        device: "devpts",
        type: "devpts",
        flags: ["rw", "nosuid", "noexec", "relatime", "gid=5", "mode=620", "ptmxmode=000"]
      },
      "/tmp" => %{
        device: "tmpfs",
        type: "tmpfs",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime", "size=50924k"]
      },
      "/run" => %{
        device: "tmpfs",
        type: "tmpfs",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime", "size=25464k", "mode=755"]
      },
      "/mnt/boot" => %{
        device: "/dev/mmcblk0p1",
        type: "vfat",
        flags: [
          "ro",
          "nosuid",
          "nodev",
          "noexec",
          "relatime",
          "fmask=0022",
          "dmask=0022",
          "codepage=437",
          "iocharset=iso8859-1",
          "shortname=mixed",
          "errors=remount-ro"
        ]
      },
      "/root" => %{
        device: "/dev/mmcblk0p4",
        type: "f2fs",
        flags: [
          "rw",
          "lazytime",
          "nodev",
          "relatime",
          "background_gc=on",
          "discard",
          "no_heap",
          "inline_data",
          "inline_dentry",
          "flush_merge",
          "extent_cache",
          "mode=adaptive",
          "active_logs=6",
          "alloc_mode=reuse",
          "fsync_mode=posix"
        ]
      },
      "/sys/fs/cgroup" => %{
        device: "tmpfs",
        type: "tmpfs",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime", "size=1024k", "mode=755"]
      },
      "/sys/fs/cgroup/cpu" => %{
        device: "cpu",
        type: "cgroup",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime", "cpu"]
      },
      "/sys/fs/cgroup/memory" => %{
        device: "memory",
        type: "cgroup",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime", "memory"]
      },
      "/sys/fs/pstore" => %{
        device: "pstore",
        type: "pstore",
        flags: ["rw", "nosuid", "nodev", "noexec", "relatime"]
      }
    }

    assert expected == MountParser.parse(mount_output)
  end

  test "ignores bad mount output" do
    assert %{} == MountParser.parse("This shouldn't happen")
    assert %{} == MountParser.parse("")
  end
end
