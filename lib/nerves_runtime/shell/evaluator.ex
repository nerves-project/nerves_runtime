defmodule Nerves.Runtime.Shell.Evaluator do
  @moduledoc """
  The evaluator is responsible for managing the shell port and executing
  commands against it.
  """

  def init(command, server, leader, _opts) do
    old_leader = Process.group_leader
    Process.group_leader(self(), leader)

    command == :ack && :proc_lib.init_ack(self())

    path = System.find_executable("sh")
    port = Port.open({:spawn_executable, path}, [:binary, :stderr_to_stdout, :eof, :exit_status])
    state = %{port: port, path: path}

    try do
      loop(server, state)
    after
      Process.group_leader(self(), old_leader)
    end
  end

  defp loop(server, state) do
    port = state.port
    receive do
      {^port, {:data, data}} ->
        IO.puts("#{data}")
        loop(server, state)
      {^port, {:exit_status, status}} ->
        IO.puts("Interactive shell port exited with status #{status}")
        :ok
      {:eval, ^server, command, shell_state} ->
        send(state.port, {self(), {:command, command}})

        # If the command changes the shell's directory, there's
        # a chance that this checks too early. In practice, it
        # seems to work for "cd".
        new_shell_state = %{shell_state | counter: shell_state.counter + 1,
                                          cwd: get_cwd(port)  }
        send(server, {:evaled, self(), new_shell_state})
        loop(server, state)
      {:done, ^server} ->
        send(port, {self(), :close})
        :ok
      other ->
        IO.inspect(other, label: "Unknown message received by Nerves host command evaluator")
        loop(server, state)
    end
  end

  defp get_cwd(port) do
    # Get the current working directory of the port via the Linux /proc mechanism
    with {:os_pid, os_pid} <- Port.info(port, :os_pid),
         {:ok, cwd} <- :file.read_link("/proc/#{os_pid}/cwd"),
      do: cwd
  end
end
