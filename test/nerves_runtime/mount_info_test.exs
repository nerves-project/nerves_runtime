# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2025 Liv Cella
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.MountInfoTest do
  use ExUnit.Case

  alias Nerves.Runtime.MountInfo

  defp read_fixture!(name) do
    Path.join([__DIR__, "..", "fixture", "proc_self_mountinfo", name])
    |> File.read!()
  end

  describe "parsing different mount configurations" do
    test "parses embedded device A mount output" do
      result = read_fixture!("device_a") |> MountInfo.parse()

      root_mount = Enum.find(result, fn m -> m.mount_point == "/" end)

      assert %{mount_source: "/dev/root", fs_type: "squashfs", mount_options: options} =
               root_mount

      assert "ro" in options

      dev_mount = Enum.find(result, fn m -> m.mount_point == "/dev" end)
      assert %{mount_source: "devtmpfs", fs_type: "devtmpfs"} = dev_mount

      root_data_mount = Enum.find(result, fn m -> m.mount_point == "/root" end)
      assert %{mount_source: "/dev/mmcblk0p4", fs_type: "f2fs"} = root_data_mount
    end

    test "parses embedded device B mount output" do
      result = read_fixture!("device_b") |> MountInfo.parse()

      root_mount = Enum.find(result, fn m -> m.mount_point == "/" end)

      assert %{mount_source: "/dev/root", fs_type: "squashfs", mount_options: options} =
               root_mount

      assert "ro" in options

      root_data_mount = Enum.find(result, fn m -> m.mount_point == "/root" end)
      assert %{mount_source: "/dev/mmcblk0p4", fs_type: "f2fs"} = root_data_mount
    end

    test "parses embedded device C mount output" do
      result = read_fixture!("device_c") |> MountInfo.parse()

      root_mount = Enum.find(result, fn m -> m.mount_point == "/" end)

      assert %{mount_source: "/dev/dm-0", fs_type: "squashfs", mount_options: options} =
               root_mount

      assert "ro" in options

      root_data_mount = Enum.find(result, fn m -> m.mount_point == "/root" end)
      assert %{mount_source: "/dev/dm-1", fs_type: "f2fs"} = root_data_mount
    end

    test "parses Raspberry Pi Zero 2 mount output" do
      result = read_fixture!("raspberry_pi_zero_2") |> MountInfo.parse()

      root_mount = Enum.find(result, fn m -> m.mount_point == "/" end)

      assert %{mount_source: "/dev/root", fs_type: "squashfs", mount_options: options} =
               root_mount

      assert "ro" in options

      boot_mount = Enum.find(result, fn m -> m.mount_point == "/boot" end)
      assert %{mount_source: "/dev/mmcblk0p1", fs_type: "vfat"} = boot_mount

      root_data_mount = Enum.find(result, fn m -> m.mount_point == "/root" end)
      assert %{mount_source: "/dev/mmcblk0p3", fs_type: "ext4"} = root_data_mount

      config_mount = Enum.find(result, fn m -> m.mount_point == "/sys/kernel/config" end)
      assert config_mount != nil
    end

    test "parses PopOS mount output" do
      result = read_fixture!("pop_os") |> MountInfo.parse()

      root_mount = Enum.find(result, fn m -> m.mount_point == "/" end)

      assert %{mount_source: "/dev/mapper/data-root", fs_type: "ext4", mount_options: options} =
               root_mount

      assert "rw" in options

      boot_efi_mount = Enum.find(result, fn m -> m.mount_point == "/boot/efi" end)
      assert %{mount_source: "/dev/nvme0n1p1", fs_type: "vfat"} = boot_efi_mount

      recovery_mount = Enum.find(result, fn m -> m.mount_point == "/recovery" end)
      assert %{mount_source: "/dev/nvme0n1p2", fs_type: "vfat"} = recovery_mount

      # Check snap mounts exist
      core20_mount = Enum.find(result, fn m -> m.mount_point == "/snap/core20/2582" end)
      assert %{fs_type: "squashfs", mount_options: snap_options} = core20_mount
      assert "ro" in snap_options

      snapd_mount = Enum.find(result, fn m -> m.mount_point == "/snap/snapd/24505" end)
      assert snapd_mount != nil
    end
  end

  test "ignores bad mount output" do
    assert [] == MountInfo.parse("This shouldn't happen")
    assert [] == MountInfo.parse("")
  end

  test "get_mounts!/0 reads from /proc/self/mountinfo" do
    if File.exists?("/proc/self/mountinfo") do
      mounts = MountInfo.get_mounts!()
      assert is_list(mounts)
      refute Enum.empty?(mounts)

      root_mount = Enum.find(mounts, fn m -> m.mount_point == "/" end)
      assert root_mount != nil
      assert is_binary(root_mount.fs_type)
      assert is_binary(root_mount.mount_source)
    else
      assert true
    end
  end

  describe "read_only?/1" do
    test "returns true for read-only mount points on embedded device A" do
      mounts = read_fixture!("device_a") |> MountInfo.parse()
      assert MountInfo.find_by_mount_point(mounts, "/") |> MountInfo.read_only?()
      assert MountInfo.find_by_mount_point(mounts, "/mnt/boot") |> MountInfo.read_only?()
    end

    test "returns false for read-write mount points on embedded device A" do
      mounts = read_fixture!("device_a") |> MountInfo.parse()
      refute MountInfo.find_by_mount_point(mounts, "/dev") |> MountInfo.read_only?()
      refute MountInfo.find_by_mount_point(mounts, "/root") |> MountInfo.read_only?()
    end

    test "returns true for read-only mount points on embedded device B" do
      mounts = read_fixture!("device_b") |> MountInfo.parse()
      assert MountInfo.find_by_mount_point(mounts, "/") |> MountInfo.read_only?()
      assert MountInfo.find_by_mount_point(mounts, "/mnt/boot") |> MountInfo.read_only?()
    end

    test "returns false for read-write mount points on embedded device B" do
      mounts = read_fixture!("device_b") |> MountInfo.parse()
      refute MountInfo.find_by_mount_point(mounts, "/dev") |> MountInfo.read_only?()
      refute MountInfo.find_by_mount_point(mounts, "/root") |> MountInfo.read_only?()
    end

    test "returns true for read-only mount points on Raspberry Pi Zero 2" do
      mounts = read_fixture!("raspberry_pi_zero_2") |> MountInfo.parse()
      assert MountInfo.find_by_mount_point(mounts, "/") |> MountInfo.read_only?()
      assert MountInfo.find_by_mount_point(mounts, "/boot") |> MountInfo.read_only?()
    end

    test "returns false for read-write mount points on Raspberry Pi Zero 2" do
      mounts = read_fixture!("raspberry_pi_zero_2") |> MountInfo.parse()
      refute MountInfo.find_by_mount_point(mounts, "/dev") |> MountInfo.read_only?()
      refute MountInfo.find_by_mount_point(mounts, "/root") |> MountInfo.read_only?()
    end

    test "returns true for read-only mount points on PopOS" do
      mounts = read_fixture!("pop_os") |> MountInfo.parse()
      # Snap packages are mounted read-only
      assert MountInfo.find_by_mount_point(mounts, "/snap/core20/2582") |> MountInfo.read_only?()
      assert MountInfo.find_by_mount_point(mounts, "/snap/snapd/24505") |> MountInfo.read_only?()
    end

    test "returns false for read-write mount points on PopOS" do
      mounts = read_fixture!("pop_os") |> MountInfo.parse()
      # PopOS root filesystem is read-write
      refute MountInfo.find_by_mount_point(mounts, "/") |> MountInfo.read_only?()
      refute MountInfo.find_by_mount_point(mounts, "/boot/efi") |> MountInfo.read_only?()
      refute MountInfo.find_by_mount_point(mounts, "/recovery") |> MountInfo.read_only?()
    end

    test "returns false for unknown mount points" do
      mounts = read_fixture!("device_a") |> MountInfo.parse()
      refute MountInfo.find_by_mount_point(mounts, "/unknown") |> MountInfo.read_only?()
    end
  end
end
