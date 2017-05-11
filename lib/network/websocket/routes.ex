defmodule Helix.Network.Websocket.Routes do

  alias Helix.Websocket.Socket, warn: false
  alias Helix.Entity.Service.API.Entity
  alias Helix.Entity.Service.API.HackDatabase
  alias Helix.Hardware.Service.API.NetworkConnection

  # TODO: Check if player's gateway is connected to specified network
  def browse_ip(socket, %{"network_id" => network, "ip" => ip}) do
    # FIXME
    account =
      socket.assigns.account
      |> Entity.get_entity_id()
      |> Entity.fetch()

    with \
      server = %{} <- NetworkConnection.get_server_by_ip(network, ip),
      entity = %{} <- Entity.fetch_server_owner(server.server_id)
    do
      hack_database_entry = HackDatabase.fetch_server_record(
        account,
        server.server_id)

      # TODO: move this to the presentation layer
      data = %{
        server_id: server.server_id,
        server_type: server.server_type,
        entity_type: entity.entity_type,
        # Defaults to nil
        password: hack_database_entry[:password]
      }

      return = %{
        status: :success,
        data: data
      }

      {:reply, {:ok, return}, socket}
    else
      _ ->
        return = %{
          status: :error,
          data: %{message: "not found"}
        }

        {:reply, {:error, return}, socket}
    end
  end
end