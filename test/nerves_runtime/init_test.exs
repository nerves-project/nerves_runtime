# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2021 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.InitTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Init

  alias Nerves.Runtime.Init

  test "usual mounted or unmounted results" do
    mounts = """
    /dev/root on / type squashfs (ro,relatime)
    /dev/mmcblk0p4 on /root type f2fs (rw,nodev,relatime,background_gc=on,discard,no_heap,inline_data,flush_merge,extent_cache,mode=adaptive,active_logs=6,fsync_mode=posix)
    """

    assert :mounted == Init.parse_mount_state("/dev/mmcblk0p4", "/root", mounts)

    assert :unmounted == Init.parse_mount_state("/dev/mmcblk0p3", "/root", mounts)
  end

  test "mounted read only when should be read-write" do
    mounts = """
    /dev/mmcblk0p4 on /root type f2fs (ro,nodev,relatime)
    """

    assert :mounted_with_error ==
             Init.parse_mount_state("/dev/mmcblk0p4", "/root", mounts)
  end
end
