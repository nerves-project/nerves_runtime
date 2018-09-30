defmodule Nerves.Runtime.Helpers do
  # This is the path on all official Nerves systems
  @iex_exs_path "/root/.iex.exs"

  @moduledoc """
  Helper functions for making the IEx prompt a little friendlier to use with
  Nerves. It is intended to be imported to minimize typing:

      iex> use Nerves.Runtime.Helpers

  For development, you may want to run

      iex> Nerves.Runtime.Helpers.install

  on the target so that the helpers get automatically imported on each boot.

  Helpers include:

   * `cmd/1`     - runs a shell command and prints the output
   * `hex/1`     - inspects a value with integers printed as hex
   * `reboot/0`  - reboots gracefully
   * `reboot!/0` - reboots immediately

  Help for all of these can be found by running:

      iex> h(Nerves.Runtime.Helpers.cmd/1)

  """

  defmacro __using__(_) do
    quote do
      import Nerves.Runtime.Helpers, except: [install: 0]
      IO.puts("Nerves.Runtime.Helpers imported. Run h(Nerves.Runtime.Helpers) for more info")
    end
  end

  @doc """
  Install the helpers so that they're autoloaded on subsequent reboots.
  """
  @spec install() :: :ok
  def install() do
    case File.exists?(@iex_exs_path) do
      false ->
        File.write!(@iex_exs_path, "use Nerves.Runtime.Helpers")
        IO.puts("Helpers installed and will be loaded on next reboot. To use")
        IO.puts("them now, run `use Nerves.Runtime.Helpers`")

      true ->
        IO.puts("#{@iex_exs_path} already exists.")
        IO.puts("Please manually add 'use Nerves.Runtime.Helpers' if it's not already there.")
    end
  end

  @doc """
  Run a command and return the exit code. This function is intended to be run
  interactively.
  """
  @spec cmd(String.t() | charlist()) :: integer()
  def cmd(str) when is_binary(str) do
    {_collectable, exit_code} = System.cmd("sh", ["-c", str], into: IO.stream(:stdio, :line))
    exit_code
  end

  def cmd(str) when is_list(str) do
    str |> to_string |> cmd
  end

  @doc """
  Print out kernel log messages
  """
  def dmesg() do
    cmd("dmesg")
    IEx.dont_display_result()
  end

  @doc """
  Shortcut to reboot a board. This is a graceful reboot, so it takes some time
  before the real reboot.
  """
  @spec reboot() :: no_return()
  defdelegate reboot(), to: Nerves.Runtime

  @doc """
  Remote immediately without a graceful shutdown. This is for the impatient.
  """
  @spec reboot!() :: no_return()
  def reboot!() do
    :erlang.halt()
  end

  @doc """
  Inspect a value with all integers printed out in hex. This is useful for
  one-off hex conversions. If you're doing a lot of work that requires
  hexadecimal output, you should consider running:

  `IEx.configure(inspect: [base: :hex])`

  The drawback of doing the above is that strings print out as hex binaries.
  """
  @spec hex(integer()) :: String.t()
  def hex(value) do
    inspect(value, base: :hex)
  end
end
