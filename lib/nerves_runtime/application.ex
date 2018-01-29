defmodule Nerves.Runtime.Application do
  @moduledoc false

  use Application

  alias Nerves.Runtime.{
    Init,
    Kernel,
    KV,
    LogTailer
  }

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(LogTailer, [:syslog], id: :syslog),
      worker(LogTailer, [:kmsg], id: :kmsg),
      supervisor(Kernel, []),
      worker(KV, []),
      worker(Init, [])
    ]

    opts = [strategy: :one_for_one, name: Nerves.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
