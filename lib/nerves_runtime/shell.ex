defmodule Nerves.Runtime.Shell do
  @moduledoc """
  Entry point for a primitive command shell available through Erlang's job
  control mode. To use, type Ctrl+G at an iex prompt to enter job control mode.
  At the prompt, type `s 'Elixir.Nerves.Runtime.Shell'` and then `c`` to
  connect to it. To return to the iex prompt, type Ctrl+G again and `c 1`.

  Here's an example session:

      iex> [Ctrl+G]
      User switch command
      --> s 'Elixir.Nerves.Runtime.Shell'
      --> j
      1  {erlang,apply,[#Fun<Elixir.IEx.CLI.1.112225073>,[]]}
      2* {'Elixir.Nerves.Runtime.Shell',start,[]}
      --> c
      Nerves Interactive Host Shell
      sh[1]> find . -name "shell.ex"
      ./lib/nerves_runtime/shell.ex
      sh[2]> [Ctrl+G]
      User switch command
      --> c 1

      nil
      iex>
  """

  alias Nerves.Runtime.Shell.Server

  @doc """
  This is the callback invoked by Erlang's shell when someone presses Ctrl+G
  and types `s Elixir.Nerves.Runtime.Shell`.
  """
  def start(opts \\ [], mfa \\ {Nerves.Runtime.Shell, :dont_display_result, []}) do
    spawn(fn ->
      # The shell should not start until the system is up and running.
      case :init.notify_when_started(self()) do
        :started -> :ok
        _        -> :init.wait_until_started()
      end

      # Make sure the OTP app fires up since we came in through the shell's
      # job control mode.
      {:ok, _} = Application.ensure_all_started(:nerves_runtime)
      :io.setopts(Process.group_leader, binary: true, encoding: :unicode)

      Server.start(opts, mfa)
    end)
  end

  def dont_display_result, do: "don't display result"
end

