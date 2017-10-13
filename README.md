# `nerves_runtime`

[![Build Status](https://travis-ci.org/nerves-project/nerves_runtime.svg)](https://travis-ci.org/nerves-project/nerves_runtime.svg)
[![Hex version](https://img.shields.io/hexpm/v/nerves_runtime.svg "Hex version")](https://hex.pm/packages/nerves_runtime)

`nerves_runtime` is a core component of Nerves. It contains applications and
libraries that are expected to be useful on all Nerves devices.

Here are some of its features:

* Generic system and filesystem initialization (suitable for use with
  [`bootloader`](https://github.com/nerves-project/bootloader))
* Introspection of Nerves system, firmware, and deployment metadata
* Device reboot and shutdown
* A small Linux kernel `uevent` application for capturing hardware change events
  and more
* IEx helpers to make life better when working from the IEx prompt
* More to come...

The following sections describe the features in more detail. For even more
information, consult the [hex docs](https://hexdocs.pm/nerves_runtime).

## System Initialization

`nerves_runtime` provides an OTP application (`nerves_runtime`) that can
initialize the system when it is started. For this to be useful,
`nerves_runtime` must be started before other OTP applications, since most will
assume that the system is already initialized before they start. To set up
`nerves_runtime` to work with `bootloader`, you will need to do the following:

1.  Include `bootloader` in `mix.exs`
2.  Include `Bootloader.Plugin` in your `rel/config.exs`
2.  Ensure that `:nerves_runtime` is at the beginning of the `init:` list in
    your `config/config.exs`:

    ```elixir
    config :bootloader,
      overlay_path: "",
      init: [:nerves_runtime, :other_app1, :other_app2],
      app: :your_app
    ```

### Kernel Modules

`nerves_runtime` will attempt to auto-load kernel modules by calling `modprobe`
using the `modalias` supplied by the device's `uevent` message. You can disable
this feature by configuring `autoload: false` in your application configuration:

```elixir
config :nerves_runtime, :kernel,
  autoload_modules: false
```

## Filesystem Initialization

Nerves systems generally ship with one or more application filesystem
partitions. These are used for persisting data that is expected to live between
firmware updates. The root filesystem cannot be used since it is mounted as
read-only by default.

`nerves_runtime` takes an unforgiving approach to managing the application
partition: if it can't be mounted as read-write, it gets re-formatted. While
filesystem corruption should be a rare event, even with unexpected loss of
power, Nerves devices may not always be accessible for manual recovery. This
default behavior provides a basic recoverability guarantee.

To verify that this recovery works, Nerves systems usually leave the application
filesystems uninitialized so that the format operation happens on the first
boot. This means that the first boot takes slightly longer than subsequent
boots.

Note that a common implementation of "reset to factory defaults" is to purposely
corrupt the application partition and reboot.

`nerves_runtime` uses firmware metadata to determine how to mount and initialize
the application partition. The following variables are important:

* `[partition].nerves_fw_application_part0_devpath` - the path to the
  application partition (e.g. `/dev/mmcblk0p3`)
* `[partition].nerves_fw_application_part0_fstype` - the type of filesystem
  (e.g. `ext4`)
* `[partition].nerves_fw_application_part0_target` - where the partition should
  be mounted (e.g. `/root` or `/mnt/appdata`)

## Nerves System and Firmware Metadata

All official Nerves systems maintain a list of key-value pairs for tracking
various information about the system. This information is not intended to be
written frequently. To get this information, you can call one of the following:

* `Nerves.Runtime.KV.get_all_active/0` - return all key-value pairs associated
  with the active firmware.
* `Nerves.Runtime.KV.get_all/0` - return all key-value pairs, including those
  from the inactive firmware, if any.
* `Nerves.Runtime.KV.get_active/1` - look up the value of a key associated with
  the active firmware.
* `Nerves.Runtime.KV.get/1` - look up the value of a key, including those from
  the inactive firmware, if any.

Global Nerves metadata includes the following:

Key                 | Build Environment Variable   | Example Value    | Description
--------------------|------------------------------|------------------|------------
`nerves_fw_active`  | -                            | `"a"`            | This key holds the prefix that identifies the active firmware metadata. In this example, all keys starting with `"a."` hold information about the running firmware.
`nerves_fw_devpath` | `NERVES_FW_DEVPATH`          | `"/dev/mmcblk0"` | This is the primary storage device for the firmware.

Firmware-specific Nerves metadata includes the following:

Key                                   | Example Value     | Description
--------------------------------------|-------------------|------------
`nerves_fw_application_part0_devpath` | `"/dev/mmcblkp3"` | The block device that contains the application partition
`nerves_fw_application_part0_fstype`  | `"ext4"`          | The application partition's filesystem type
`nerves_fw_application_part0_target`  | `"/root"`         | Where to mount the application partition
`nerves_fw_architecture`              | `"arm"`           | The processor architecture (Not currently used)
`nerves_fw_author`                    | `"John Doe"`      | The person or company that created this firmware
`nerves_fw_description`               | `"Stuff"`         | A description of the project
`nerves_fw_platform`                  | `"rpi3"`          | A name to identify the board that this runs on. It can be checked in the `fwup.conf` before performing an upgrade.
`nerves_fw_product`                   | `"My Product"`    | A product name that may show up in a firmware selection list, for example
`nerves_fw_version`                   | `"1.0.0"`         | The project's version
`nerves_fw_vcs_identifier`            | `"bdeead38..."`   | A `git` SHA or other identifier (optional)
`nerves_fw_misc`                      | `"anything..."`   | Any application info that doesn't fit in another field (optional)

Note that the keys are stored in the environment block prefixed by the firmware
slot for which they pertain. For example, `a.nerves_fw_description` is the
description for the firmware in the "A" slot.

Several of the keys can be set in the `mix.exs` file of your main Nerves
project. This is the preferred way to set them because it requires the least
amount of effort.

Assuming that your `fwup.conf` respects the `fwup` variable names listed in the
table, the keys can also be overridden by setting environment variables at build
time. Depending on your project, you may prefer to set them using a customized
`fwup.conf` configuration file instead.

The `fwup -m` value shows the key that you'll see if you run `fwup -m -i
<project.fw>` to extract the firmware metadata from the `.fw` file.

Key in `Nerves.Runtime`               | Key in `mix.exs`            | Build Environment Variable            | Key in `fwup -m`
--------------------------------------|-----------------------------|---------------------------------------|-----------------
`nerves_fw_application_part0_devpath` | N/A                         | `NERVES_FW_APPLICATION_PART0_DEVPATH` | N/A
`nerves_fw_application_part0_fstype`  | N/A                         | `NERVES_FW_APPLICATION_PART0_FSTYPE`  | N/A
`nerves_fw_application_part0_target`  | N/A                         | `NERVES_FW_APPLICATION_PART0_TARGET`  | N/A
`nerves_fw_architecture`              | N/A                         | `NERVES_FW_ARCHITECTURE`              | `meta-architecture`
`nerves_fw_author`                    | `:author`                   | `NERVES_FW_AUTHOR`                    | `meta-author`
`nerves_fw_description`               | `:description`              | `NERVES_FW_DESCRIPTION`               | `meta-description`
`nerves_fw_platform`                  | N/A                         | `NERVES_FW_PLATFORM`                  | `meta-platform`
`nerves_fw_product`                   | `:name`                     | `NERVES_FW_PRODUCT`                   | `meta-product`
`nerves_fw_version`                   | `:version`                  | `NERVES_FW_VERSION`                   | `meta-version`
`nerves_fw_vcs_identifier`            | N/A                         | `NERVES_FW_VCS_IDENTIFIER`            | `meta-vcs-identifier`
`nerves_fw_misc`                      | N/A                         | `NERVES_FW_MISC`                      | `meta-misc`

## Device Reboot and Shutdown

Rebooting, powering-off, and halting a device work by signaling to
[`erlinit`](https://github.com/nerves-project/erlinit) an intention to shutdown
and then exiting the Erlang VM by calling `:init.stop/0`. The
`Nerves.Runtime.reboot/0` and related utilities are helper methods for this.
Once they return, the Erlang VM will likely only be available momentarily before
shutdown. If the OTP applications cannot be stopped within a timeout as
specified in the `erlinit.config`, `erlinit` will ungracefully terminate the
Erlang VM.

## IEx helpers

The `Nerves.Runtime.Helpers` module provides a number of functions that are
useful when working at the IEx prompt on a target. They include:

* `cmd/1` - runs a shell command and prints the output
* `hex/1` - inspects a value in hexadecimal mode
* `reboot/0` - reboots gracefully
* `reboot!/0 ` - reboots immediately

More information is available in the module docs for `Nerves.Runtime.Helpers`
and through `h/1`.

The IEx helpers aren't loaded by default. To use them, run the following:
```
iex> use Nerves.Runtime.Helpers
```

If you expect to use them frequently, add them to your `.iex.exs` on the
target by running:

```
iex> File.write!("/root/.iex.exs", "use Nerves.Runtime.Helpers")
```

## Installation

The package can be installed by adding `nerves_runtime` to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [{:nerves_runtime, "~> 0.2.0"}]
end
```

More detailed documentation can be found at
[https://hexdocs.pm/nerves_runtime](https://hexdocs.pm/nerves_runtime).
