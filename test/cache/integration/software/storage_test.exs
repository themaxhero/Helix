defmodule Helix.Cache.Integration.Software.StorageTest do

  use Helix.Test.Case.Integration

  import Helix.Test.Case.Cache

  alias Helix.Software.Internal.Storage, as: StorageInternal
  alias Helix.Cache.Internal.Builder, as: BuilderInternal
  alias Helix.Cache.Internal.Cache, as: CacheInternal
  alias Helix.Cache.Internal.Populate, as: PopulateInternal
  alias Helix.Test.Cache.Helper, as: CacheHelper
  alias Helix.Cache.State.PurgeQueue, as: StatePurgeQueue

  setup do
    CacheHelper.cache_context()
  end

  describe "storage deletion" do
    test "it cleans the cache", context do
      server_id = context.server.server_id

      # Populate on the DB
      {:ok, server} = PopulateInternal.populate(:by_server, server_id)
      assert {:hit, _} = CacheInternal.direct_query(:server, server_id)

      storage_id = Enum.random(server.storages)

      # Delete storage
      storage_id
      |> StorageInternal.fetch()
      |> StorageInternal.delete()

      # Marks storage for deletion, obviously
      assert StatePurgeQueue.lookup(:storage, storage_id)

      # But the server too, since it exists on the cache
      assert StatePurgeQueue.lookup(:server, server_id)

      StatePurgeQueue.sync()

      # Storage no longer saved on cache
      assert_miss CacheInternal.direct_query(:storage, storage_id)

      # Server no long lists that storage
      assert {:hit, server} = CacheInternal.direct_query(:server, server_id)
      storage_ids = Enum.map(server.storages, &to_string/1)
      refute to_string(storage_id) in storage_ids
    end

    test "it cleans the cache (cold)", context do
      server_id = context.server.server_id

      # Generate entry but do not save it on DB
      {:ok, server} = BuilderInternal.by_server(server_id)

      storage_id = Enum.random(server.storages)

      # Delete storage
      storage_id
      |> StorageInternal.fetch()
      |> StorageInternal.delete()

      # Always purge storage
      assert StatePurgeQueue.lookup(:storage, storage_id)

      # But do not purge server, since it doesnt exists anwyay
      refute StatePurgeQueue.lookup(:server, server_id)

      StatePurgeQueue.sync()

      assert_miss CacheInternal.direct_query(:storage, storage_id)
      assert_miss CacheInternal.direct_query(:server, server_id)
    end
  end
end
