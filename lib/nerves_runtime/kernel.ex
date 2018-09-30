defmodule Nerves.Runtime.Kernel do
  use Supervisor
  alias Nerves.Runtime.Kernel

  @moduledoc """
  Supervisor for kernel-related tasks.
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(_args) do
    Supervisor.start_link(__MODULE__, [], name: Kernel.Supervisor)
  end

  def init([]) do
    kernel_opts = Application.get_env(:nerves_runtime, :kernel)

    children = [
      {Kernel.UEvent, kernel_opts}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
