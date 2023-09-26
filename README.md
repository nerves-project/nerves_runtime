# nerves_runtime

[![CircleCI](https://circleci.com/gh/nerves-project/nerves_runtime.svg?style=svg)](https://circleci.com/gh/nerves-project/nerves_runtime)
[![Hex version](https://img.shields.io/hexpm/v/nerves_runtime.svg "Hex version")](https://hex.pm/packages/nerves_runtime)

`nerves_runtime` is a core component of Nerves. It contains applications and
libraries that are expected to be useful on all Nerves devices.

Here are its features:

* Generic system and filesystem initialization (suitable for use with
  [`shoehorn`](https://github.com/nerves-project/shoehorn))
* Introspection of Nerves system, firmware, and deployment metadata
* Device reboot and shutdown
* A small Linux kernel `uevent` application for capturing hardware change events
  and more. See [`nerves_uevent`](https://github.com/nerves-project/nerves_uevent).
* Device serial numbers
* Linux log integration with Elixir. See [`nerves_logging`](https://github.com/nerves-project/nerves_logging)

The following sections describe the features in more detail. For more
information, see the [hex docs](https://hexdocs.pm/nerves_runtime).

## System Initialization

`nerves_runtime` provides an OTP application (`nerves_runtime`) that can
initialize the system when it is started. For this to be useful,
`nerves_runtime` must be started before other OTP applications, since most will
assume that the system is already initialized before they start. To set up
`nerves_runtime` to work with `shoehorn`, you will need to do the following:

1. Add `shoehorn` to your `mix.exs` dependency list
2. Add a `:shoehorn` configuration to `config.exs` and `:nerves_runtime` to the
   beginning of the `init:` list:

```elixir
config :shoehorn,
  init: [:nerves_runtime, :other_app1, :other_app2]
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

A common implementation of "reset to factory defaults" is to purposely erase
(corrupt) the application partition and reboot. See
`Nerves.Runtime.FwupOps.factory_reset/1`.

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
------------------- | ---------------------------- | ---------------- | -----------
`nerves_fw_active`  | N/A                          | `"a"`            | This key holds the prefix that identifies the active firmware metadata. In this example, all keys starting with `"a."` hold information about the running firmware.
`nerves_fw_devpath` | `NERVES_FW_DEVPATH`          | `"/dev/mmcblk0"` | This is the primary storage device for the firmware.
`nerves_serial_number` | N/A                       | `"12345abc"`     | This is a text serial number. See [Serial numbers](#serial_numbers) for details.
`nerves_fw_validated` | N/A                        | `0`              | Set to "1" to indicate that the currently running firmware is valid. (Only supported on some platforms)
`nerves_fw_autovalidate` | N/A                     | `1`              | Set to "1" to indicate that firmware updates are valid without any additional checks.  (Only supported on some platforms)
`upgrade_available` | N/A                          | `0`              | If using the U-Boot bootloader AND U-Boot's `bootcount` feature, then the `upgrade_available` variable is used instead of `nerves_fw_validated` (it has the opposite meaning)
`bootcount`         | N/A                          | `1`              | If using the U-Boot bootloader AND U-Boot's `bootcount` feature, then this is the number of times an unvalidated firmware has been booted.
`bootlimit`         | N/A                          | `1`              | If using the U-Boot bootloader AND U-Boot's `bootcount` feature, then this is the max number of tries for unvalidated firmware.

Firmware-specific Nerves metadata includes the following:

Key                                   | Example Value     | Description
:------------------------------------ | :---------------- | :----------
`nerves_fw_application_part0_devpath` | `"/dev/mmcblk0p3"` | The block device that contains the application partition
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
project.fw` to extract the firmware metadata from the `.fw` file.

Key in `Nerves.Runtime`               | Key in `mix.exs`            | Build Environment Variable            | Key in `fwup -m`
------------------------------------- | --------------------------- | ------------------------------------- | ----------------
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

## Reverting firmware

If you'd like to go back to the previous version of firmware running on a
device, you can do that if the Nerves system supports it. At the IEx prompt,
run:

```elixir
iex> Nerves.Runtime.revert
```

Running this command manually is useful in development. Production use requires
more work to protect against faulty upgrades.

Newer Nerves systems support preventing a revert. This is useful when you've
loaded a version of firmware that is not meant to be used after it has been
upgraded. This could be a factory test or an initial firmware that bootstraps
encrypted firmware storage. See `Nerves.Runtime.FwupOps.prevent_revert/0`.

### Assisted firmware validation and automatic revert

Nerves firmware updates protect against update corruption and power loss
midway into the update procedure. However, what happens if the firmware update
contains bad code that hangs the device or breaks something important like
networking? Some Nerves systems support tentative runs of new firmware and if
something goes wrong, they'll revert back.

At a high level, this involves some additional code from the developer that
knows what constitutes "working". This could be "is it possible to connect to
the firmware update server within 5 minutes of boot?"

Here's the process:

1. New firmware is installed in the normal manner. The `Nerves.Runtime.KV`
   variable, `nerves_fw_validated` is set to 0. (The systems `fwup.conf` does
   this)
2. The system reboots like normal.
3. The device starts a five minute reboot timer (your code needs to do this if
   you want to catch hangs or super-slow boots)
4. The application attempts to make a connection to the firmware update server.
5. On a good connection, the application sets `nerves_fw_validated` to 1 by
   calling `Nerves.Runtime.validate_firmware/0` and cancels the reboot timer.
6. On error, the reboot timer failing, or a hardware watchdog timeout, the
   system reboots. The bootloader reverts to the previous firmware.

Some Nerves systems support a KV variable called `nerves_fw_autovalidate`. The
intention of this variable was to make that system support scenarios that
require validate and ones that don't. If the system supports this variable then
you should make sure that it is set to 0 (either via a custom fwup.conf or via
the provisioning hooks for writing serial numbers to MicroSD cards). Support for
the `nerves_fw_autovalidate` variable will likely go away in the future as steps
are made to make automatic revert on bad firmware a default feature of Nerves
rather than an add-on.

### U-Boot assisted automatic revert

U-Boot provides a `bootcount` feature that can be used to try out new firmware
and revert it if it fails. At a high level, it works similar to logic just
described except that it can attempt a new firmware more than once if desired. This
can help if validating a firmware image depends on factors out of your control and
you want a few tries to happen before giving up.

To use this, you need to enable the following U-Boot configuration items:

```text
CONFIG_BOOTCOUNT_LIMIT=y
CONFIG_BOOTCOUNT_ENV=y
```

See the U-Boot documentation for more information. The gist is to have your
`bootcmd` handle normal booting and then add an `altbootcmd` to revert the
firmware. The firmware update should set the `upgrade_available` U-Boot
environment variable to `"1"` to indicate that boot counting should start.
`Nerves.Runtime.validate_firmware/0` knows about `upgrade_available`, so when
you call it to indicate that the firmware is ok, it will set `upgrade_available`
back to `"0"` and reset `"bootcount"`.

### Best effort automatic revert

Unfortunately, the bootloader for platforms like the Raspberry Pi makes it
difficult to implement the above mechanism. The following strategy cannot
protect against kernel and early boot issues, but it can still provide value:

1. Upgrade firmware the normal way. Record that the next boot will be the first
   one in the application data partition.
2. On the reboot, if this is the first one, record that the boot happened and
   revert the firmware with `reboot: false`.  If this is not the first boot,
   carry on.
3. When you're happy with the new firmware, revert the firmware again with
   `reboot: false`. I.e., revert the revert. It is critical that `revert` is
   only called once.

To make this handle hangs, you'll want to enable a hardware watchdog.

## Serial numbers

Finding the serial number of a device is both hardware specific and influenced
by you and your organization's choices for assigning them (or not). Programs
should call `Nerves.Runtime.serial_number/0` to get the serial number.

Nerves systems all come with some default way of getting a serial number for a
device. This strategy will likely work for a while, but may not meet your needs
when it comes to production. Nerves uses
[`boardid`](https://github.com/nerves-project/boardid/) to read serial numbers
and it can be customized via its `/etc/boardid.config` file. See `boardid` for
the mechanisms available. If none of `boardid`'s mechanisms work for you, please
consider filing an issue or making a PR, since our history has been that
organizations tend to use similar mechanisms and it's likely someone else will
use it too.

As a word of caution, many Nerves users write serial numbers in the U-Boot
environment block under the key `nerves_serial_number`. This is supported and
documentation exists for it in many places. While it's very convenient, it has
drawbacks - like it's easily modified. It's definitely not the only mechanism.
The `boardid.config` file supports trying multiple ways of getting a serial
number to handle hardware changing over the course of development.

See
[embedded-elixir](https://embedded-elixir.com/post/2018-06-15-serial_number/)
for how to assign serial numbers to devices using the U-Boot environment block
way.

## Using nerves_runtime in tests

Applications that depend on `nerves_runtime` for accessing provisioning
information from the `Nerves.Runtime.KV` can mock the contents with the included
`Nerves.Runtime.KVBackend.InMemory` module through the Application config:

```elixir
config :nerves_runtime,
  kv_backend: {Nerves.Runtime.KVBackend.InMemory, contents: %{"key" => "value"}}
```

You can also create your own module based on the `Nerves.Runtime.KVBackend`
behavior and set it to be used in the Application config. In most situations,
the provided `Nerves.Runtime.KVBackend.InMemory` should be sufficient, though
this would be helpful in cases where you might need to generate the initial
state at runtime instead:

```elixir
defmodule MyApp.KVBackend.Mock do
  @behaviour Nerves.Runtime.KVBackend

  @impl Nerves.Runtime.KVBackend
  def load(_opts) do
    # initial state
    %{
      "howdy" => "partner",
      "dynamic" => some_runtime_calc_function()
    }
  end

  @impl Nerves.Runtime.KVBackend
  def save(_map, _opts), do: :ok
end

# Then in config.exs
config :nerves_runtime, :kv_backend, MyApp.KVBackend.Mock
```
