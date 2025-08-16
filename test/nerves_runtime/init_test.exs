# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2021 Frank Hunleth
# SPDX-FileCopyrightText: 2025 Liv Cella
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.InitTest do
  use ExUnit.Case
  doctest Nerves.Runtime.Init

  alias Nerves.Runtime.Init
  alias Nerves.Runtime.MountInfo

  test "usual mounted or unmounted results" do
    mount_output = """
    13 1 179:2 / / ro,relatime - squashfs /dev/root ro
    21 13 179:4 / /root rw,nodev,relatime - f2fs /dev/mmcblk0p4 rw,lazytime,background_gc=on,discard,no_heap,inline_data,inline_dentry,flush_merge,extent_cache,mode=adaptive,active_logs=6,alloc_mode=reuse,fsync_mode=posixs
    """

    mounts = MountInfo.parse(mount_output)

    assert :mounted == Init.mount_point_state(mounts, "/root")

    assert :unmounted == Init.mount_point_state(mounts, "/nonexistent")
  end

  test "mounted read only when should be read-write" do
    mount_output = """
    21 13 179:4 / /root ro,nodev,relatime - f2fs /dev/mmcblk0p4 ro,lazytime,background_gc=on,discard,no_heap,inline_data,inline_dentry,flush_merge,extent_cache,mode=adaptive,active_logs=6,alloc_mode=reuse,fsync_mode=posix
    """

    mounts = MountInfo.parse(mount_output)

    assert :mounted_with_error ==
             Init.mount_point_state(mounts, "/root")
  end
end
