# Changelog

## v0.11.8 - 2021-10-25

* Changes
  * Update the mix dependencies to allow `uboot_env v1.0.0` to be used.

## v0.11.7

* Bug fixes
  * `Nerves.Runtime.firmware_valid?/0` would return that the firmware wasn't
    validated when the validation feature wasn't in use. This was confusing
    since firmware is assumed valid when the feature is off.

## v0.11.6

* New features
  * Added support for implementing auto-revert logic using U-Boot's
    bootcount/upgrade_available feature. This can simplify U-Boot scripts. See
    the README.md for details.

* Bug fixes
  * Specify "-f" to force f2fs filesystem formats like those of other
    filesystems. Thank to Eric Rauer for catching this oversight.

## v0.11.5

* Updates
  * If `/etc/sysctl.conf` is present, run `sysctl` to load and set the kernel
    configuration parameters in it.
  * Improve C compilation messages and error help

## v0.11.4

* Updates
  * Added `Nerves.Runtime.firmware_valid?/0` to easily check whether the
    firmware has been marked valid for systems that auto-rollback.

## v0.11.3

* Updates
  * Support `uboot_env` v0.3.0. This version of `uboot_env` has backwards
    incompatible changes, but they don't affect `nerves_runtime`, so the
    `mix.exs` deps spec allows it now.
  * Tightened up the specs on `Nerves.Runtime.KV` functions.

Support for OTP 20 was removed. `uboot_env` v0.3.0 requires OTP 21 and later. If
you still are using OTP 20, lock the version of `uboot_env` to `~> 0.2.0` in
your `mix.exs`.

## v0.11.2

* New features
  * Added `Nerves.Runtime.validate_firmware/0` for validating firmware on
    systems that auto-rollback. This *only* abstracts the setting of the
    `nerves_fw_validated` key. It doesn't add any new functionality. However, it
    will enable auto-rollback to be added to Nerves systems in a consistent
    manner in the future and allow for platform-specific variations without
    impacting application code.

## v0.11.1

* Bug fixes
  * Reap zombie process that was created by the uevent port helper.
  * Support `uboot_env` v0.2.0 to reduce memory garbage that's created when
    reading and writing U-Boot environment blocks

## v0.11.0

* New features
  * Add `Nerves.Runtime.serial_number/0`. It will call out to the underlying
    system to return the device's serial number however it's stored.
  * Add a fallback to `haveged` for systems that don't have hardware random
    number generators or otherwise can't use `rngd`.

## v0.10.3

* Bug fixes
  * Fix potential process accumulation from the kmsg_tailer process ignoring
    stdin being closed on it.
  * Tightened deps to avoid combinations that would be difficult to support

## v0.10.2

* Bug fixes
  * Fix off-by-one error when processing uevent messages with device paths
    longer than 16 segments. This also bumps the max number of segments to 32.
  * Fix logger message about `rngd` failing when it was successful
  * Log errors when required commands aren't available rather than raising. It
    turned out that raising was disabling logging and that was making it hard to
    figure out the root cause.

* Enhancements
  * Switch from parsing `/proc/kmsg` to `/dev/kmsg` for kernel messages. The
    device interface supplies a little more information and is unaffected by
    other programs reading from it. This change refactored syslog/kmsg parsing
    to improve test coverage. This is considered to be an internal API. If you
    were using it, you will need to update your code.

## v0.10.1

* Bug fixes
  * Fix exception on init when mounting the application data partition.
    This addresses an issue where `:nerves_runtime` would exit due to an
    unmatched call to `System.cmd/3`.

## v0.10.0

* New feature
  * Added `Nerves.Runtime.KV.put` and `Nerves.Runtime.KV.put_active` to support
    setting environment. This removes the need to run `fw_setenv` and also
    updates the cached key/value pairs. Thanks to Troels Brødsgaard for
    implementing.

## v0.9.5

* Bug fixes
  * Fix C compiler error (PATH_MAX undeclared) on x86_64/muslc systems

## v0.9.4

* Enhancements
  * Reduced number of syscalls needed for transferring device detection events
    (uevents) to Elixir by batching them
  * Improved start up performance by moving initial device enumeration to C
  * Handle uevent overloads by dropping messages rather than crashing. Uevent
    bursts are handled better by the new batching, but can be more severe due to
    faster enumeration. Both dropping and crashing have drawbacks, but dropping
    made it possible to recover on a 32-processor machine with many peripherals.

## v0.9.3

* Enhancements
  * Move C build products to under `_build`

## v0.9.2

* Enhancements
  * Support disabling SystemRegistry integration. This is not a recommended
    setting and should only be used on slow devices that don't need device
    insertion/removal notifications.

## v0.9.1

* Enhancements
  * Filter out `synth_uuid` from uevent reports since it's not supported by the
    current uevent handling code.
  * Further reduce garbage produced by processing uevent reports

## v0.9.0

The Nerves Runtime Helpers have been extracted and are now part of
[Toolshed](https://hex.pm/packages/toolshed). The helpers included things like
`cmd/1` and `reboot/0` that you could run at the IEx prompt. Toolshed is not
included as a dependency. If you would like it, please add `toolshed` to your
application dependencies. You'll find that Toolshed contains more helpers. It is
also easier for us to maintain since changes to the helpers no longer affect
all Nerves projects.

* Enhancements
  * Further optimize enumeration of devices at boot. This fixes an issue where
    uniprocessor boards (like the RPi Zero and BBB) would appear to stall
    momentarily on boot.
  * The U-Boot environment processing code has been factored out of
    `nerves_runtime` so that it can be used independently from Nerves. It can be
    found at [uboot_env](https://hex.pm/packages/uboot_env).

## v0.8.0

* Enhancements
  * Optimized enumeration of devices at boot. You will likely notice devices
    becoming available more quickly. This may uncover race conditions in
    application initialization code.
  * The `syslog` monitoring code has been rewritten in pure Elixir. This
    component captures log messages sent by C programs using the `syslog` system
    call so that they can be handled by Elixir Logger backends.
  * The kmsg log monitor still requires C, but the C code is simpler now that it
    doesn't process `syslog` messages as well.
  * The Linux `uevent` processing code was simplified and the C to Elixir
    communications refactored to minimize processing of events.

* Bug fixes
  * Fixed a race condition with the Linux kernel and processing `/sys/devices`
    that could cause an exception during device enumeration.
  * Syslog messages w/o terminating newlines are logged now.

## v0.7.0

* Enhancements
  * Documentation updates to `nerves_serial_number`, `nerves_validated`, and
    `nerves_autovalidate`.
  * Added helper function `Nerves.Runtime.KV.UBootEnv.put/2` for writing to the
    UBoot env. This is useful for setting provisioning information at runtime.
  * Added the ability to mock the contents of `Nerves.Runtime.KV` for use in
    test and dev. The contents can be set in your application config.

      config :nerves_runtime, :modules, [
        {Nerves.Runtime.KV.Mock, %{"key" => "value"}}
      ]

* Bug fixes
  * Kernel uevent `change` messages no longer cause modifications to
    system_registry.

## v0.6.5

Update dependencies to only include `dialyxir` for `[:dev, :test]`, preventing
it from being distributed in the with the hex package. This addresses an issue
where `dialyxir` and its dependencies would be included in the applications list
when producing the OTP release and cause `:wx` to raise because the target
version of `erts` was compiled without it.

## v0.6.4

* Bug fixes
  * Fix U-Boot environment load issue and add unit tests to cover environment
    block generation using either U-Boot tools or fwup
  * Load rngd if available. If it's available, this greatly shortens the time
    for the Linux kernel's random number entropy pool to initialize. This
    improves boot time for applications that need random numbers right away.

## v0.6.3

* Bug fixes
  * Fix issue with parsing fw_env.config files with space separated values.

## v0.6.2

* Enhancements
  * Updates to docs and typespecs.

* Bug fixes
  * Read the U-Boot environment directly using :file if possible. (OTP-21)
    This fixes an issue with `fw_printenv` where multi-line values cause the
    output to be unparseable.

## v0.6.1

* Bug fixes
  * Log the output of system commands to that they're easier to review
  * Support mounting `f2fs` (requires support in the Nerves system to work)

## v0.6.0

* New features
  * Forward operating system messages from `/dev/log` and `/proc/kmsg` to
    Elixir's `Logger`. If the log volume is too much to the console, consider
    replacing the console logger with `ring_logger` or another logger backend.

* Bug Fixes
  * `cmd/1` helper improvements to interactively print output from long running
    commands.
  * `Nerves.Runtime.revert` would always reboot even if told not to.
  * Cleanup throughout to improve docs, formatting, and newer Elixir stylistic
    conventions
  * Remove scary suid printout when crosscompiling since nothing setuid related
    was going on.

## v0.5.2

* Enhancements
  * Added `Nerves.Runtime.revert` to revert the device to the inactive
    firmware. To use this, the Nerves system needs to include revert
    instructions. This is currently being implemented.

* Bug Fixes
  * Setuid the `uevent` port binary for debugging on the host.

## v0.5.1

* Bug Fixes
  * Split device attributes into only two parts

## v0.5.0

* The Nerves runtime shell (the bash shell-like shell from CTRL+G) has been
  moved to a separate project so that it can evolve independently from
  `nerves_runtime`. As such, it's no longer available, but see
  the `nerves_runtime_shell` project to include it again.

* Enhancements
  * Force application partition UUID. The UUID has previously been random. The
    main reason for change is to avoid a delay when waiting for the urandom
    pool to initialize. Having a known UUID for the application partition may
    come in handy in the future, though.

## v0.4.4

* Enhancements
  * Added installation helper for `Nerves.Runtime.Helpers`
  * Privatized methods in KV so that they don't show up in the tab complete
    and help screens.

## v0.4.3

* Enhancements
  * The `Nerves.Runtime.Helpers` module provides a number of functions that are
    useful when working at the IEx prompt on a target.

## v0.4.2

* Enhancements
  * Makefile only builds for Linux hosts or cross compile environments. Allows
    package to compile on other platforms.

## v0.4.1

* Bug Fixes
  * Fixed issue with the order of args being passed to mkfs

## v0.4.0

* Enhancements
  * Loosen dependency requirements on SystemRegistry

## v0.3.1

* Bug Fixes
  * Increased erl_cmd buffer size to 2048 to prevent segfaults with uevents for
    devices with many attributes.

## v0.3.0

* Enhancements
  * Removed GenStage in favor of SystemRegistry
  * Added KV firmware variable key value store
  * Added Init worker for initializing the application partition

## v0.2.0

* Enhancements
  * Moved hardware abstraction layer to separate project for further
    development
  * Start the shell using the name `sh` instead of `'Elixir.Nerves.Runtime.Shell'`

## v0.1.2

* Bug fixes
  * Cleaned up IO
  * Rename host to sh
