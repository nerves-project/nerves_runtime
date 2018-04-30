defmodule Nerves.Runtime.Application do
  @moduledoc false

  use Application

  alias Nerves.Runtime.{
    Init,
    Kernel,
    KV,
    LogTailer,
    ConfigFS
  }

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(LogTailer, [:syslog], id: :syslog),
      worker(LogTailer, [:kmsg], id: :kmsg),
      supervisor(Kernel, []),
      worker(KV, []),
      worker(Init, []),
      worker(ConfigFS, [])
    ]

    opts = [strategy: :one_for_one, name: Nerves.Runtime.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
