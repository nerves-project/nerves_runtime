defmodule Nerves.Runtime.Helpers do
  @moduledoc """
  Helper functions for making the IEx prompt a little friendlier to use
  with Nerves. It is intended to be imported to minimize typing:

      iex> use Nerves.Runtime.Helpers

  For development, you may want to run

      iex> File.write!("/root/.iex.exs", "use Nerves.Runtime.Helpers")

  on the target so that it gets imported automatically.

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
      import Nerves.Runtime.Helpers
      IO.puts("Nerves.Runtime.Helpers imported. Run h(Nerves.Runtime.Helpers) for more info")
    end
  end

  @doc """
  Run a command using :os.cmd/1 and run its output
  through IO.puts so that newlines get printed nicely.
  """
  def cmd(str) when is_binary(str) do
    cmd(to_charlist(str))
  end
  def cmd(str) when is_list(str) do
    :os.cmd(str) |> IO.puts
  end

  @doc """
  Shortcut to reboot a board. This is a graceful reboot, so it takes
  some time before the real reboot.
  """
  defdelegate reboot(), to: Nerves.Runtime

  @doc """
  Remote immediately without a graceful shutdown. This is for the
  impatient.
  """
  def reboot!() do
    Nerves.Runtime.reboot()
    :erlang.halt()
  end

  @doc """
  Inspect a value with all integers printed out in hex. This is useful
  for one-off hex conversions. If you're doing a lot of work that requires
  hexadecimal output, you should consider running:

  `IEx.configure(inspect: [base: :hex])`

  The drawback of doing the above is that strings print out as hex binaries.
  """
  def hex(value) do
    inspect(value, base: :hex)
  end

end
