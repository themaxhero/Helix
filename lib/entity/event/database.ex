defmodule Helix.Entity.Event.Database do

  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Software.Model.SoftwareType.Cracker.ProcessConclusionEvent
  alias Helix.Entity.Action.Database, as: DatabaseAction
  alias Helix.Entity.Query.Entity, as: EntityQuery

  def cracker_conclusion(event = %ProcessConclusionEvent{}) do
    entity = EntityQuery.fetch(event.entity_id)
    server = ServerQuery.fetch(event.server_id)
    %{ip: server_ip} = ServerQuery.get_ip(event.server_id, event.network_id)

    create_entry = fn ->
      DatabaseAction.create(
        entity,
        event.network_id,
        event.server_ip,
        event.server_id,
        event.server_type)
    end

    set_password = fn ->
      DatabaseAction.update(
        entity,
        event.network_id,
        event.server_ip,
        %{password: server.password})
    end

    if to_string(server_ip) == to_string(event.server_ip) do
      {:ok, _} = create_entry.()
      {:ok, _} = set_password.()
    end
  end
end
