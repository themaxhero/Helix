defmodule Helix.HELFRouter.App do
  use Application

  @port Application.get_env(:helf_router, :port)

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(HELF.Router, [@port])
    ]

    opts = [strategy: :one_for_one, name: HELFRouter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end