# Changelog

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
