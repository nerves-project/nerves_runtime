defmodule Nerves.Runtime.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Nerves.Runtime.Kernel, []),
      worker(Nerves.Runtime.KV, []),
      worker(Nerves.Runtime.Init, [])
    ]

    opts = [strategy: :one_for_one, name: Nerves.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
