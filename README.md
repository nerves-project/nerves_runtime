# Nerves.Runtime

[![Build Status](https://travis-ci.org/nerves-project/nerves_runtime.svg)](https://travis-ci.org/nerves-project/nerves_runtime.svg)
[![Hex version](https://img.shields.io/hexpm/v/nerves_runtime.svg "Hex version")](https://hex.pm/packages/nerves_runtime)

Nerves.Runtime is a core component of Nerves. It contains applications and
libraries that are expected to be useful on all Nerves devices.  Here are some
of its features:

* Generic system and filesystem initialization (suitable for use with
  [bootloader](https://github.com/nerves-project/bootloader))
* Introspection of Nerves system firmware and deployment metadata
* A custom shell for debugging and running commands in a `bash` shell like
  environment
* Device reboot and shutdown
* A small Linux kernel `uevent` application for capturing hardware change events
  and more
* More to come...

The following sections describe the features in more detail. For even more
information, consult the [hex docs](https://hexdocs.pm/nerves_runtime).

## System initialization

Nerves.Runtime provides an OTP application that can initialize the system when
it is started. For this to be useful, Nerves.Runtime must be started before
other OTP applications especially since non-Nerves-aware applications almost
certainly won't know that they need this to work. Specific initialization is
detailed in other sections. To set Nerves.Runtime up with `bootloader`, you will
need to do the following (luckily this should become easier as this new
functionality propagates through templates and examples.)

1. Ensure that `bootloader` is included in your `mix.exs` and the
   `Bootloader.Plugin` is in your `rel/config.exs`.
2. In your `config/config.exs`, make sure that `:nerves_runtime` is at the
   beginning of the `init:` list:

```elixir
config :bootloader,
  overlay_path: "",
  init: [:nerves_runtime, :other_app],
  app: :your_app
```

### Kernel Modules

Nerves.Runtime will attempt to autoload kernel modules by calling `modprobe`
using the `modalias` supplied from the uevent message for devices. You can
disable this feature by configuring `autoload: false` in your application config.

```elixir
config :nerves_runtime, :kernel,
  autoload_modules: false
```

## Filesystem initialization

Nerves systems generally ship with one or more application filesystem
partitions. These are used for persisting data that's expected to live between
firmware updates. The root filesystem cannot be used since it is mounted
read-only in Nerves.

Nerves.Runtime takes an unforgiving approach to managing the application
partition: if it can't be mounted read-write, it gets re-formatted. While
filesystem corruption should be a rare event even on unexpected powerdowns with
modern filesystems, Nerves devices may not be easily accessed to perform any
kind of recovery. This allows for at least some functionality.

To verify that this recovery works, Nerves systems usually leave the application
filesystems uninitialized so that the format operation happens on the first
boot. This means that the first boot takes slightly longer than others.

Note that a common implementation of "reset to factory" defaults is to
purposefully corrupt the application partition and reboot.

Nerves.Runtime uses firmware metadata to determine how to mount and initialize
the application partition. The following variables are important:

* `[partition].nerves_fw_application_part0_devpath` - the path to the
  application partition. E.g., `/dev/mmcblk0p3`
* `[partition].nerves_fw_application_part0_fstype` - the type of filesystem.
  E.g., `ext4`
* `[partition].nerves_fw_application_part0_target` - where the partition should
  be mounted. E.g., `/root` or `/mnt/appdata`

## Nerves system and firmware metadata

All official Nerves systems maintain a short list of key-value pairs for
tracking the running firmware version, etc. and other system information. This
information is not intended to be written frequently. To get this information,
call one of the following:

* `Nerves.Runtime.KV.get_all_active/0` - return all key-value pairs associated
  with the actively running firmware.
* `Nerves.Runtime.KV.get_active/0` - return all key-value pairs. This includes
  key-value pairs associated with the non-running firmware in an A/B partitioned
  system.
* `Nerves.Runtime.KV.get_active/1` - look up the value of a key associated with
  the currently running firmware.
* `Nerves.Runtime.KV.get/1` - look up the value of a key

Global Nerves metadata includes the following:

Key               | Build env variable | Example value  | Description
------------------|--------------------|----------------|------------
nerves_fw_active  | -                  | "a"            | This key holds the prefix that identifies the actively running firmware metadata. In this example, all keys starting with "a." hold information about the running firmware.
nerves_fw_devpath | NERVES_FW_DEVPATH  | "/dev/mmcblk0" | This is the primary storage device for the firmware.

Firmware-specific Nerves metadata includes the following. Note that the keys are
stored in the environment block prefixed by the firmware slot for which they
pertain. E.g., `a.nerves_fw_description` is the description for the firmware in
the "A" slot.

Key                                 | mix.exs project key | Build environment variable          | fwup -m           | Example value   | Description
------------------------------------|---------------------|-------------------------------------|-------------------|-----------------|---------------
nerves_fw_application_part0_devpath | -                   | NERVES_FW_APPLICATION_PART0_DEVPATH | -                 | "/dev/mmcblkp3" | The block device that contains the application partition
nerves_fw_application_part0_fstype  | -                   | NERVES_FW_APPLICATION_PART0_FSTYPE  | -                 | "ext4"          | The application partition's filesystem type (see the mount command for options)
nerves_fw_application_part0_target  | -                   | NERVES_FW_APPLICATION_PART0_TARGET  | -                 | "/root"         | Where to mount the application partition.
nerves_fw_architecture              | -                   | NERVES_FW_ARCHITECTURE              | meta-architecture | "arm"           | The processor architecture. Not currently used.
nerves_fw_author                    | :author             | NERVES_FW_AUTHOR                    | meta-author       | "John Doe"      | The person or company that created this firmware.
nerves_fw_description               | :description        | NERVES_FW_DESCRIPTION               | meta-description  | "Stuff"         | A description of the project
nerves_fw_platform                  | -                   | NERVES_FW_PLATFORM                  | meta-platform     | "rpi3"          | A name to identify the board that this runs on. It can be checked in the fwup.conf before performing an upgrade.
nerves_fw_product                   | :name               | NERVES_FW_PRODUCT                   | meta-product      | "My Product"    | A product name that may show up in a firmware selection list, for example.
nerves_fw_version                   | :version            | NERVES_FW_VERSION                   | meta-version      | "1.0.0"         | The project's version

As shown above, several keys can be set in the `mix.exs` file or your main
Nerves project. That is also the preferred location of setting them. Assuming
that the `fwup.conf` respects the `fwup` variable names above, those are all
overridable by setting environment variables. Overriding the `fwup.conf`
provided by the Nerves system may be a preferrable way of setting them, though.

The `fwup -m` column shows the key that you'll see if you run
`fwup -m -i <project.fw>` to extract the firmware metadata from the `.fw` file.

## Device reboot and shutdown

Reboot, poweroff, and halting a device work by signaling to
[erlinit](https://github.com/nerves-project/erlinit) an intention to shutdown
and then exiting the Erlang VM by calling `:init.stop/0`. The
`Nerves.Runtime.reboot/0` and related utilities are helper methods for this.
Once they return, the Erlang VM will likely only be available momentarily before
shutdown. If the OTP applications cannot be stopped within a timeout as
specified in the `erlinit.config`, `erlinit` will ungracefully terminate the
Erlang VM.

## The Nerves Runtime Shell

Nerves devices typically only expose an Elixir or Erlang shell prompt. While
this is handy, some tasks are quicker to run in a more `bash` shell-like
environment. The Nerves runtime shell provides a limited approximation to this
that can be run without leaving the Erlang runtime. Here's an example run:

```
iex(1)> [Ctrl+G]
User switch command
 --> s sh
 --> j
   1  {erlang,apply,[#Fun<Elixir.IEx.CLI.1.112225073>,[]]}
   2* {sh,start,[]}
 --> c
Nerves Interactive Command Shell

Type Ctrl+G to exit the shell and return to Erlang job control.
This is not a normal shell, so try not to type Ctrl+C.

/srv/erlang[1]>
```

There are a few caveats to using this shell right now, so you'll have to be
careful when you use it:

1. `Ctrl+C Ctrl+C` exits the Erlang VM and will reboot or hang your system
   depending on how `erlinit` is configured.
2. Because of the `Ctrl+C` caveat, you can't easily break out of long running
   programs. As a workaround, start another shell using `Ctrl+G` and `kill` the
   offending program.
3. Commands are run asynchronously. This is unexpected if you're used to a
   regular shell. For most commands, it's harmless. One side effect is that if a
   command changes the current directory, it could be that the prompt shows the
   wrong path.

## Installation

The package can be installed
by adding `nerves_runtime` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:nerves_runtime, "~> 0.2.0"}]
end
```

Docs can be found at [https://hexdocs.pm/nerves_runtime](https://hexdocs.pm/nerves_runtime).
