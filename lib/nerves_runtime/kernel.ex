defmodule Nerves.Runtime.Kernel do
  use Supervisor
  alias Nerves.Runtime.Kernel

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: Kernel.Supervisor)
  end

  def init([]) do
    kernel_opts = Application.get_env(:nerves_runtime, :kernel)

    children = [
      worker(Kernel.UEvent, [kernel_opts])
    ]

    supervise(children, strategy: :one_for_one)
  end
end
