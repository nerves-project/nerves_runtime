# SPDX-FileCopyrightText: 2022 Frank Hunleth
# SPDX-FileCopyrightText: 2025 Liv Cella
#
# SPDX-License-Identifier: Apache-2.0
defmodule Nerves.Runtime.MountInfo do
  @moduledoc """
  Utilities for getting information about mounted filesystems
  Mount information is parsed from /proc/self/mountinfo. For complete field
  descriptions, see the [Linux manual](https://man7.org/linux/man-pages/man5/proc_pid_mountinfo.5.html).
  """
  require Logger

  @typedoc """
  A list of mount records
  """
  @type mount_info() :: [mount_record()]

  @typedoc """
  Information about a single mount point

  Each mount record contains the following fields:

  * `mount_id` - a unique identifier for the mount
  * `parent_id` - the ID of the parent mount
  * `major_minor` - the major:minor device number
  * `root` - the pathname of the directory in the filesystem which forms the root of this mount
  * `mount_point` -  the pathname of the mount point relative to the process's root directory
  * `mount_options` - per-mount options
  * `optional_fields` - zero or more fields of the form `tag[:value]`
  * `fs_type` - the filesystem type in the form `type[.subtype]`
  * `mount_source` - filesystem-specific information or `none`
  * `super_options` - per-superblock options
  """
  @type mount_record() :: %{
          mount_id: integer(),
          parent_id: integer(),
          major_minor: String.t(),
          root: String.t(),
          mount_point: String.t(),
          mount_options: [String.t()],
          optional_fields: [String.t()],
          fs_type: String.t(),
          mount_source: String.t(),
          super_options: [String.t()]
        }

  @doc """
  Returns information about all mounted filesystems

  Raises an exception if /proc/self/mountinfo cannot be read, since this file
  is guaranteed to exist on Nerves and Linux systems.
  """
  @spec get_mounts!() :: mount_info()
  def get_mounts!() do
    File.read!("/proc/self/mountinfo")
    |> parse()
  end

  @doc """
  Find mount information by its mount point
  """
  @spec find_by_mount_point(mount_info(), String.t()) :: mount_record() | nil
  def find_by_mount_point(mounts \\ get_mounts!(), target) do
    Enum.find(mounts, fn mount -> mount.mount_point == target end)
  end

  @doc """
  Parses mountinfo content into a list of mount_info structs.
  """
  @spec parse(String.t()) :: mount_info()
  def parse(mountinfo_contents) do
    mountinfo_contents
    |> String.split("\n", trim: true)
    |> Enum.flat_map(&parse_mountinfo_line/1)
  end

  defp parse_mountinfo_line(line) do
    with [left, right] <- String.split(line, " - ", parts: 2),
         [mount_id, parent_id, major_minor, root, mount_point, mount_options | optional_fields] <-
           String.split(left, " ", trim: true),
         [fs_type, mount_source, super_options] <- String.split(right, " ", trim: true) do
      [
        %{
          mount_id: String.to_integer(mount_id),
          parent_id: String.to_integer(parent_id),
          major_minor: major_minor,
          root: root,
          mount_point: mount_point,
          mount_options: String.split(mount_options, ","),
          optional_fields: optional_fields,
          fs_type: fs_type,
          mount_source: mount_source,
          super_options: String.split(super_options, ",")
        }
      ]
    else
      _ -> []
    end
  end

  @doc """
  Checks if a mount point is mounted read-only

  This checks the mount options to see if the file system was mounted
  read-only. It could have originally been mounted writable, but an
  error caused Linux to automatically remount it read-only.
  """
  @spec read_only?(mount_record()) :: boolean()
  def read_only?(mount_record) when is_nil(mount_record), do: false

  def read_only?(mount_record) when is_map(mount_record) do
    Enum.member?(mount_record.mount_options, "ro")
  end
end
