import Helix.Websocket.Request

request Helix.Universe.Bank.Websocket.Requests.CreateAccount do
  @moduledoc """
  BankCreateAccountRequest is used when the player want to create
  a BankAccount on given bank.

  It Returns :ok or :error
  """
  alias Helix.Server.Model.Server
  alias Helix.Server.Henforcer.Server, as: ServerHenforcer
  alias Helix.Server.Query.Server, as: ServerQuery
  alias Helix.Universe.Bank.Public.Bank, as: BankPublic
  alias Helix.Universe.Bank.Henforcer.Bank, as: BankHenforcer

  def check_params(request, _socket) do
    with \
     {:ok, atm_id} <- Server.ID.cast(request.unsafe["atm_id"]),
     {:ok, gateway_id} <- Server.ID.cast(request.unsafe["gateway"])
    do
      params =
        %{
          atm_id: atm_id,
          gateway_id: gateway_id
        }

      update_params(request, params, reply: true)
    else
      _ ->
        bad_request(request)
    end
  end

  @doc """
  Checks if player can open BankAccount, most of logic is delegated to
  BankHenforcer.can_create_account?/1
  """
  def check_permissions(request, _socket) do
    atm = ServerQuery.fetch(request.params.atm_id)
    with \
      {true, r1} <- BankHenforcer.can_create_account?(atm),
      atm_id = r1.atm_id,
      {true, r2} <- ServerHenforcer.server_exists?(request.params.gateway_id)
    do
      meta =
       %{
          atm_id: atm_id,
          gateway_id: r2.server.server_id
        }

      update_meta(request, meta, reply: true)
    else
      {false, reason, _} ->
        reply_error(request, reason)
      _ ->
        bad_request(request)
    end
  end

  def handle_request(request, socket) do
    atm_id = request.meta.atm_id
    account_id = socket.assigns.account_id
    gateway = ServerQuery.fetch(request.meta.gateway_id)
    atm = ServerQuery.fetch(atm_id)
    relay = request.relay

    process = BankPublic.open_account(gateway, account_id, atm, relay)
    case process do
      {:ok, process} ->
        update_meta(request, %{process: process}, reply: true)
      {:error, reason} ->
        reply_error(request, reason)
    end
  end
  render_empty()
end
