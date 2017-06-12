# Nerves.Runtime

[![Build Status](https://travis-ci.org/nerves-project/nerves_runtime.svg)](https://travis-ci.org/nerves-project/nerves_runtime.svg)
[![Hex version](https://img.shields.io/hexpm/v/nerves_runtime.svg "Hex version")](https://hex.pm/packages/nerves_runtime)

Nerves.Runtime is an optional component of Nerves but it's really handy and has
a small footprint. Here are some of its features:

* A custom shell for debugging and running commands in a `bash` shell like
  environment
* A small Linux kernel `uevent` application for capturing hardware change events
  and more
* More to come...

## The Nerves Runtime Shell

Nerves devices typically only expose an Elixir or Erlang shell prompt. While
this is handy, so tasks are quicker to run in a more `bash` shell-like
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
  [{:nerves_runtime, "~> 0.1.2"}]
end
```

Docs can be found at [https://hexdocs.pm/nerves_runtime](https://hexdocs.pm/nerves_runtime).
