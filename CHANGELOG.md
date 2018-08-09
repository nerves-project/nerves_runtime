# Changelog

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
  * Makefile only builds for Linux hosts or cross compile environments. Allows package to compile on other platforms.

## v0.4.1

* Bug Fixes
  * Fixed issue with the order of args being passed to mkfs

## v0.4.0

* Enhancements
  * Loosen dependency requirements on SystemRegistry

## v0.3.1

* Bug Fixes
  * Increased erl_cmd buffer size to 2048 to prevent segfaults with uevents for devices with many attributes.

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
