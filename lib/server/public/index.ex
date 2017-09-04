defmodule Helix.Server.Public.Index do

  import HELL.MacroHelpers

  alias Helix.Cache.Query.Cache, as: CacheQuery
  alias Helix.Entity.Model.Entity
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Log.Public.Index, as: LogIndex
  alias Helix.Network.Model.Network
  alias Helix.Network.Model.Tunnel
  alias Helix.Network.Public.Index, as: NetworkIndex
  alias Helix.Network.Query.Tunnel, as: TunnelQuery
  alias Helix.Process.Public.Index, as: ProcessIndex
  alias Helix.Software.Public.Index, as: FileIndex
  alias Helix.Server.Model.Server
  alias Helix.Server.Query.Server, as: ServerQuery

  @type index ::
    %{
      player: [gateway_server],
      remote: [remote_server]
    }

  @type rendered_index ::
    %{
      player: [rendered_gateway_server],
      remote: [rendered_remote_server]
    }

  @type gateway_server ::
    %{
      id: Server.id,
      name: String.t,
      password: Server.password,
      nips: [Network.nip],
      logs: LogIndex.index,
      filesystem: FileIndex.index,
      processes: ProcessIndex.index,
      tunnels: NetworkIndex.index,
      endpoints: [Server.id]
    }

  @type rendered_gateway_server ::
    %{
      id: String.t,
      name: String.t,
      password: String.t,
      nips: [[String.t]],
      logs: LogIndex.rendered_index,
      filesystem: FileIndex.rendered_index,
      processes: ProcessIndex.index,
      tunnels: NetworkIndex.rendered_index,
      endpoints: [String.t]
    }

  @type remote_server ::
    %{
      id: Server.id,
      nips: [Network.nip],
      logs: LogIndex.index,
      filesystem: FileIndex.index,
      processes: ProcessIndex.index,
      tunnels: NetworkIndex.index,
      bounces: [Server.id]
    }

  @type rendered_remote_server ::
    %{
      id: String.t,
      nips: [[String.t]],
      logs: LogIndex.rendered_index,
      filesystem: FileIndex.rendered_index,
      processes: ProcessIndex.index,
      tunnels: NetworkIndex.rendered_index,
      bounces: [String.t]
    }

  @spec index(Entity.id) ::
    index
  @doc """
  Returns the server index, which encompasses all other indexes residing under
  the context of server, like Logs, Filesystem, Processes, Tunnels etc.

  Called on Account bootstrap (as opposed to `remote_server_index`, which is
  used after a player logs into a remote server)
  """
  def index(entity_id) do
    player_servers =
      entity_id
      |> EntityQuery.fetch()
      |> EntityQuery.get_servers()

    # Get all endpoints (any remote server the player is SSH-ed to)
    endpoints = TunnelQuery.get_remote_endpoints(player_servers)

    %{local: local_servers, remote: remote_servers} =
      player_servers
      |> Enum.map(&(gateway_server(&1, entity_id, endpoints)))
      |> Enum.reduce(%{remote: [], local: []}, fn {gateway, remotes}, acc ->
        acc
        |> Map.replace(:local, acc.local ++ [gateway])
        |> Map.replace(:remote, acc.remote ++ remotes)
    end)

    # Remove duplicate remotes, if any. This may happen if two different gateway
    # servers are connected to the same remote
    unique_remotes = Enum.uniq_by(remote_servers, &(&1.id))

    %{
      player: local_servers,
      remote: unique_remotes
    }
  end

  @spec render_index(index) ::
    rendered_index
  @doc """
  Top-level renderer for Server Index (generated by `index/1`)
  """
  def render_index(index) do
    %{
      player: Enum.map(index.player, &(render_gateway_server(&1))),
      remote: Enum.map(index.remote, &(render_remote_server(&1)))
    }
  end

  def remote_server_index(_server_id, _entity_id) do
    # TODO
  end

  @spec gateway_server(Server.id, Entity.id, Tunnel.remote_endpoints) ::
    {gateway_server, [remote_server]}
  docp """
  Generates one server entry under the context of gateway (i.e. this server
  belongs to the player). It also generates one entry for each server that
  gateway is connected to.

  Scenario:
  - On Account bootstrap, return servers owned by the player
  """
  defp gateway_server(server_id, entity_id, connections) do
    endpoints =
      if connections[server_id] do
        connections[server_id]
        |> Enum.map(&(&1.destination_id))
      else
        []
      end

    server = ServerQuery.fetch(server_id)
    name = "Server1"

    index = %{
      endpoints: endpoints,
      password: server.password,
      name: name
    }

    gateway = Map.merge(server_common(server_id, entity_id), index)

    remotes =
      if connections[server_id] do
        Enum.map(connections[server_id], fn remote ->
          remote_server(remote.destination_id, entity_id, remote.bounces)
        end)
      else
        []
      end

    {gateway, remotes}
  end

  @spec render_gateway_server(gateway_server) ::
    rendered_gateway_server
  docp """
  Renderer for `gateway_server/3`
  """
  defp render_gateway_server(server) do
    partial = %{
      endpoints: Enum.map(server.endpoints, &(to_string(&1))),
      password: server.password,
      name: server.name
    }

    Map.merge(partial, render_server_common(server))
  end

  @spec remote_server(Server.id, Entity.id, bounces :: [Server.id]) ::
    remote_server
  docp """
  Generates one server entry under the context of endpoint (i.e. this server
  does not belong to the player who made the request).

  Scenarios:
  - on Account bootstrap, display remote servers I'm connected to
  - after login into remote server, gibes me information about it.
  """
  defp remote_server(server_id, entity_id, bounces) do
    index = %{
      bounces: bounces
    }

    Map.merge(server_common(server_id, entity_id), index)
  end

  @spec render_remote_server(remote_server) ::
    rendered_remote_server
  docp """
  Renderer for `remote_server/3`
  """
  defp render_remote_server(server) do
    partial = %{
      bounces: Enum.map(server.bounces, &(to_string(&1)))
    }

    Map.merge(partial, render_server_common(server))
  end

  @spec server_common(Server.id, Entity.id) ::
    term
  docp """
  Common values to both local and remote servers being generated.
  """
  defp server_common(server_id, entity_id) do
    {:ok, nips} = CacheQuery.from_server_get_nips(server_id)

    log_index = LogIndex.index(server_id)
    filesystem_index = FileIndex.index(server_id)
    tunnel_index = NetworkIndex.index(server_id)
    process_index = ProcessIndex.index(server_id, entity_id)

    %{
      id: server_id,
      nips: nips,
      logs: log_index,
      filesystem: filesystem_index,
      processes: process_index,
      tunnels: tunnel_index
    }
  end

  @spec render_server_common(gateway_server | remote_server) ::
    term
  docp """
  Renderer for `server_common/2`.
  """
  defp render_server_common(server) do
    nips = Enum.map(server.nips, fn nip ->
      [to_string(nip.network_id), nip.ip]
    end)

    %{
      id: to_string(server.id),
      nips: nips,
      logs: LogIndex.render_index(server.logs),
      filesystem: FileIndex.render_index(server.filesystem),
      processes: server.processes,
      tunnels: NetworkIndex.render_index(server.tunnels)
    }
  end
end
