# Changelog
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
