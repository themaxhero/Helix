defmodule Helix.Test.Universe.Bank.Websocket.Requests.CreateAccountTest do

  use Helix.Test.Case.Integration

  alias Helix.Websocket.Requestable
  alias Helix.Entity.Model.Entity
  alias Helix.Network.Query.Network, as: NetworkQuery
  alias Helix.Universe.Bank.Websocket.Requests.CreateAccount,
    as: BankCreateAccountRequest

  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Server.Setup, as: ServerSetup
  alias Helix.Test.Universe.NPC.Helper, as: NPCHelper

  describe "BankCreateAccountRequest.check_params/2" do
    test "accepts when receives valid information" do
      # Setups an Account socket.
      {socket, %{account: account}} = ChannelSetup.create_socket()

      entity_id = Entity.ID.cast!(to_string(account.account_id))

      # Setups an Server new Server to created account
      {gateway, _} = ServerSetup.server(entity_id: entity_id)

      # Gets a Bank from database.
      {bank, _} = NPCHelper.bank
      atm_id = List.first(bank.servers).id

      # Creates the parameters for creating a account.
      payload =
      %{
        "atm_id" => to_string(atm_id),
        "gateway" => to_string(gateway.server_id)
      }

      # Creates a new BankCreateAccountRequest with the parameters.
      request =
        BankCreateAccountRequest.new(payload)

      # Asserts that given parameters are okay.
      assert {:ok, request} =
        Requestable.check_params(request, socket)

      # Assert the parameters after checking are right.
      assert request.params.atm_id == atm_id
    end

    test "rejects when receives invalid atm_id" do
      # Setups an Account socket.
      {socket, _} = ChannelSetup.create_socket()

      # Creates invalid parameters.
      payload =
      %{
        "atm_id" => "DROP TABLE helix_dev_accounts;",
        "gateway" => "FROM *"
      }

      # Create BankCreateAccountRequest with invalid parameters.
      request =
        BankCreateAccountRequest.new(payload)

      # Asserts that given parameters are rejected.
      assert {:error, reason, _} =
        Requestable.check_params(request, socket)

      # Asserts that the error message is "bad_request.
      assert reason.message == "bad_request"
    end
  end

  describe "BankCreateAccountRequest.check_permissions/2" do
    test "accepts when the ATM is a bank" do
      # Setups an Account socket.
      {socket, %{account: account}} = ChannelSetup.create_socket()

      entity_id = Entity.ID.cast!(to_string(account.account_id))

      # Setups an Server new Server to created account
      {gateway, _} = ServerSetup.server(entity_id: entity_id)

      # Gets a Bank and it's atm_id.
      {bank, _} = NPCHelper.bank
      atm_id = List.first(bank.servers).id

      # Create valid parameters.
      payload =
      %{
        "atm_id" => to_string(atm_id),
        "gateway" => to_string(gateway.server_id)
      }

      # Create BankCreateAccountRequest with valid parameters.
      request =
        BankCreateAccountRequest.new(payload)

      # Checks if parameters are valid.
      {:ok, request} =
        Requestable.check_params(request, socket)

      # Asserts that Bank is a Bank.
      assert {:ok, request} =
        Requestable.check_permissions(request, socket)

      # Asserts that atm_id is on meta.
      assert request.meta.atm_id == atm_id
    end

    test "rejects when the ATM is not a server" do
      # Setups an Account socket.
      {socket, %{account: account}} = ChannelSetup.create_socket()

      entity_id = Entity.ID.cast!(to_string(account.account_id))

      # Setups an Server new Server to created account
      {gateway, _} = ServerSetup.server(entity_id: entity_id)

      # Setups a ordinary server.
      {not_bank, _} = ServerSetup.server()

      # Create parameters passing the ordinary server's id as
      # an atm_id.
      payload =
      %{
        "atm_id" => to_string(not_bank.server_id),
        "gateway" => to_string(gateway.server_id)
      }

      # Create BankCreateAccountRequest with parameters.
      request =
        BankCreateAccountRequest.new(payload)

      # Asserts the parameters are in right format.
      assert {:ok, request} =
        Requestable.check_params(request, socket)

      # Asserts error because the ordinary server is not a bank.
      assert {:error, reason, _} =
        Requestable.check_permissions(request, socket)

      # Asserts the error message is "atm_not_a_bank".
      assert reason.message == "atm_not_a_bank"
    end
  end

  describe "BankCreateAccountRequest.handle_request/2" do
    test "creates BankAccount on database" do
      # Setups an Account socket.
      {socket, %{account: account}} = ChannelSetup.create_socket()

      entity_id = Entity.ID.cast!(to_string(account.account_id))

      # Setups an Server new Server to created account
      {gateway, _} = ServerSetup.server(entity_id: entity_id)

      # Gets a Bank and it's atm_id.
      {bank, _} = NPCHelper.bank
      atm_id = List.first(bank.servers).id

      # Creates valid parameters.
      payload =
      %{
        "atm_id" => to_string(atm_id),
        "gateway" => to_string(gateway.server_id)
      }

      # Creates a BankCreateAccountRequest with the parameters.
      request =
        BankCreateAccountRequest.new(payload)

      # Checks if parameters are in correct format.
      {:ok, request} =
        Requestable.check_params(request, socket)

      # Checks if the given bank is a bank.
      {:ok, request} =
        Requestable.check_permissions(request, socket)

      # Asserts that the request is handled correctly.
      assert {:ok, request} =
        Requestable.handle_request(request, socket)
    end
  end
end
