defmodule Helix.Cache.Internal.Populate do
  @moduledoc """
  `Populate` is responsible for, well, populating the cache.

  In order to gather the "actual" data, it uses other services' Query modules.
  Since these services *own* that data, Cache can trust it is accurate.

  `Populate` is called dynamically by `Helix.Cache.Internal.Cache` every time
  a "miss" happens, i.e. the requested data was not cached. It then proceeds
  to figure out what the current data is (using `populate`), caching it.

  It is designed in such a way to have independent data models, each with their
  own logic for populating the cache database.
  """

  alias Helix.Cache.Repo
  alias Helix.Cache.Model.ServerCache
  alias Helix.Cache.Model.NetworkCache
  alias Helix.Cache.Model.StorageCache
  alias Helix.Cache.Model.ComponentCache
  alias Helix.Cache.Internal.Cache, as: CacheInternal
  alias Helix.Cache.State.PurgeQueue, as: StatePurgeQueue
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Hardware.Query.Component, as: ComponentQuery
  alias Helix.Hardware.Query.Motherboard, as: MotherboardQuery
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Software.Query.Storage, as: StorageQuery

  import HELL.MacroHelpers

  @doc """
  Populates the corresponding model, based on its primary key.

  These functions are quite expensive in the sense that they may have to query
  several different services in order to compile a denormalized cache.
  """
  def populate(:server, server_id) do
    entity = EntityQuery.fetch_server_owner(server_id)

    with \
      server = %{} <- ServerQuery.Origin.fetch(server_id) || :nxserver,
      true <- not is_nil(server.motherboard_id) || :nxmobo,
      motherboard = %{} <- MotherboardQuery.Origin.fetch_by_server(server_id),
      motherboard = MotherboardQuery.Origin.preload_components(motherboard),
      resources = %{} <- MotherboardQuery.Origin.resources(motherboard),
      components = MotherboardQuery.Origin.get_component_ids(motherboard),
      storages = MotherboardQuery.Origin.get_storages(motherboard),
      networks = MotherboardQuery.Origin.get_networks(motherboard)
    do
      data = {server_id, entity, motherboard, networks, storages, resources,
              components}
      cache(:server, data)
    else
      :nxmobo ->
        cache(:server, {server_id, entity, nil, nil, nil, nil, nil})
      :nxserver ->
        {:error, :nxserver}
      _ ->
        {:error, :unknown}
    end
  end
  def populate(:storage, storage_id) do
    with \
      [drive_id|_] = StorageQuery.get_drive_ids(storage_id),
      motherboard_id = ComponentQuery.Origin.get_motherboard_id(drive_id),
      true <- not is_nil(motherboard_id) || :unlinked,
      server = %{} <- ServerQuery.Origin.fetch_by_motherboard(motherboard_id)
    do
      cache(:storage, {storage_id, server.server_id})
    else
      :unlinked ->
        {:error, :unlinked}
      _ ->
        {:error, :unknown}
    end
  end
  def populate(:component, component_id) do
    case ComponentQuery.Origin.get_motherboard_id(component_id) do
      nil ->
        {:error, :unlinked}
      motherboard_id ->
        cache(:component, {component_id, motherboard_id})
    end
  end
  def populate(:network, network_id, ip) do
    case ServerQuery.Origin.fetch_by_nip(network_id, ip) do
      nil ->
        {:error, :unknown}
      server ->
        cache(:network, {network_id, ip, server.server_id})
    end
  end

  docp """
  Formats the compiled data and inserts into the DB.
  """
  defp cache(:server, data = {server_id, _, mobo, networks, storages, _, components}) do
    params = format(:server, data)

    unless is_nil(mobo) do
      storage_ids = Enum.map(storages, &(&1.storage_id))

      purge_list = [
        {:server, [server_id]},
        {:component, [mobo.motherboard_id]}
      ]

      networks_purge = Enum.reduce(networks, [], fn(network, acc) ->
        [{:network, [network.network_id, network.ip]}] ++ acc
      end)

      components_purge = Enum.map(components, &({:component, [&1]}))

      storages_purge = Enum.map(storage_ids, &({:storage, [&1]}))

      purge_list
      |> Kernel.++(networks_purge)
      |> Kernel.++(components_purge)
      |> Kernel.++(storages_purge)
      |> CacheInternal.mark_multiple_as_purged()

      spawn(fn() ->
        store(:server, params)

        # Network
        Enum.each(networks, fn(network) ->
          cache(:network, {network.network_id, network.ip, server_id})
        end)

        # Storage
        Enum.each(storage_ids, &cache(:storage, {&1, server_id}))

        # Components
        Enum.each(components, fn(component) ->
          cache(:component, {component, mobo.motherboard_id})
        end)

        # Motherboard
        cache(:component, {mobo.motherboard_id, mobo.motherboard_id})
      end)
    else
      CacheInternal.mark_as_purged(:server, server_id)

      spawn(fn() ->
        store(:server, params)
      end)
    end

    {:ok, params}
  end
  defp cache(:network, data) do
    params = format(:network, data)
    CacheInternal.mark_as_purged(:network, [params.network_id, params.ip])
    store(:network, params)
  end
  defp cache(:storage, data) do
    params = format(:storage, data)
    CacheInternal.mark_as_purged(:storage, params.storage_id)
    store(:storage, params)
  end
  defp cache(:component, data) do
    params = format(:component, data)
    CacheInternal.mark_as_purged(:component, params.component_id)
    store(:component, params)
  end

  defp format(:server, {server, entity, mobo, _, _, _, _}) when is_nil(mobo) do
    %{
      server_id: server,
      entity_id: entity.entity_id,
      motherboard_id: nil,
      components: nil,
      resources: nil,
      storages: nil,
      networks: nil
    }
  end
  defp format(:server, {server, entity, mobo, networks, storages, resources, components}) do

    network_list = Enum.reduce(networks, [], fn(net, acc) ->
      entry = %{network_id: net.network_id, ip: net.ip}

      acc ++ [entry]
    end)

    storage_list = Enum.map(storages, &(&1.storage_id))

    %{
      server_id: server,
      entity_id: entity.entity_id,
      motherboard_id: mobo.motherboard_id,
      components: components,
      resources: resources,
      storages: storage_list,
      networks: network_list
    }
  end
  defp format(:network, {network_id, ip, server_id}) do
    %{
      network_id: network_id,
      ip: ip,
      server_id: server_id
    }
  end
  defp format(:storage, {storage_id, server_id}) do
    %{
      storage_id: storage_id,
      server_id: server_id
    }
  end
  defp format(:component, {component_id, motherboard_id}) do
    %{
      component_id: component_id,
      motherboard_id: motherboard_id
    }
  end


  docp """
  Saves the cache on the database. If it already exists, it updates its contents
  along with the new expiration time.
  """
  defp store(:server, params) do
    result = params
    |> ServerCache.create_changeset()
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:server_id])

    case result do
      {:ok, _} ->
        StatePurgeQueue.unqueue(:server, [params.server_id])
        result
      _ ->
        result
    end
  end
  defp store(:network, params) do
    result = params
    |> NetworkCache.create_changeset()
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:network_id, :ip])

    case result do
      {:ok, _} ->
        StatePurgeQueue.unqueue(:network, [params.network_id, params.ip])
        result
      _ ->
        result
    end
  end
  defp store(:storage, params) do
    result = params
    |> StorageCache.create_changeset()
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:storage_id])

    case result do
      {:ok, _} ->
        StatePurgeQueue.unqueue(:storage, [params.storage_id])
        result
      _ ->
        result
    end
  end
  defp store(:component, params) do
    result = params
    |> ComponentCache.create_changeset()
    |> Repo.insert(on_conflict: :replace_all, conflict_target: [:component_id])

    case result do
      {:ok, _} ->
        StatePurgeQueue.unqueue(:component, [params.component_id])
        result
      _ ->
        result
    end
  end
end
