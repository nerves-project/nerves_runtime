defmodule Nerves.Runtime.InitTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Init

  alias Nerves.Runtime.Init

  test "usual mounted or unmounted results" do
    mounts = """
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

    assert :mounted == Init.parse_mount_state("/dev/mmcblk0p4", "/root", mounts)

    assert :unmounted == Init.parse_mount_state("/dev/mmcblk0p3", "/root", mounts)
  end

  test "mounted read only when should be read-write" do
    mounts = """
    /dev/root on / type squashfs (ro,relatime)
    /dev/mmcblk0p1 on /mnt/boot type vfat (ro,nosuid,nodev,noexec,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro)
    /dev/mmcblk0p4 on /root type f2fs (ro,nodev,relatime)
    """

    assert :mounted_with_error ==
             Init.parse_mount_state("/dev/mmcblk0p4", "/root", mounts)
  end
end
