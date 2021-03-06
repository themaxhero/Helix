defmodule Helix.Network.Public.NetworkTest do

  use Helix.Test.Case.Integration

  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Network.Public.Network, as: NetworkPublic

  alias HELL.TestHelper.Random
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Universe.NPC.Helper, as: NPCHelper
  alias Helix.Test.Network.Helper, as: NetworkHelper
  alias Helix.Test.Network.Web.Setup, as: WebSetup

  @internet NetworkHelper.internet_id()

  describe "browse/3" do
    test "valid resolution of VPC IP" do
      {target_server, _} = ServerSetup.server()
      {gateway, _} = ServerSetup.server()

      target_ip = ServerQuery.get_ip(target_server.server_id, @internet)

      assert {:ok, result, relay} =
        NetworkPublic.browse(@internet, target_ip, gateway)

      assert result.type == :vpc
      assert result.content == %{}
      refute result.password
      refute result.subtype
      assert relay.server_id == target_server.server_id
    end

    test "valid resolution of NPC IP" do
      {gateway, _} = ServerSetup.server()
      {dc, dc_ip} = NPCHelper.download_center()

      dc_server_id = NPCHelper.get_server_id(dc)

      assert {:ok, result, relay} =
        NetworkPublic.browse(@internet, dc_ip, gateway)

      assert result.type == :npc
      assert result.content == WebSetup.npc(dc.id, dc_ip)
      assert result.subtype
      refute result.password
      assert relay.server_id == dc_server_id
    end

    test "returns web_not_found error when IP doesnt exists" do
      {gateway, _} = ServerSetup.server()

      assert {:error, error_msg} =
        NetworkPublic.browse(@internet, Random.ipv4(), gateway)

      assert error_msg == %{message: "web_not_found"}
    end
  end
end
