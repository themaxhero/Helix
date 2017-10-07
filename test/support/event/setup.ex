defmodule Helix.Test.Event.Setup do

  alias Helix.Entity.Model.Entity
  alias Helix.Server.Model.Server

  alias Helix.Process.Model.Process.ProcessCreatedEvent
  alias Helix.Universe.Bank.Model.BankTokenAcquiredEvent
  alias Helix.Universe.Bank.Model.BankAccount.LoginEvent,
    as: BankAccountLoginEvent
  alias Helix.Universe.Bank.Model.BankAccount.PasswordRevealedEvent,
    as: BankAccountPasswordRevealedEvent

  alias HELL.TestHelper.Random
  alias Helix.Test.Process.Setup, as: ProcessSetup

  ##############################################################################
  # Process events
  ##############################################################################

  @doc """
  Accepts:

  - (gateway :: Server.ID, target :: Server.ID, gateway_entity :: Entity.ID \
    target_entity_id :: Entity.ID), in which case a fake process with random ID
    is generated
  """
  def process_created(gateway_id, target_id, gateway_entity, target_entity) do
    # Generates a random process on the given server(s)
    process_opts = [gateway_id: gateway_id, target_id: target_id]
    {process, _} = ProcessSetup.fake_process(process_opts)

    %ProcessCreatedEvent{
      process: process,
      gateway_id: gateway_id,
      target_id: target_id,
      gateway_entity_id: gateway_entity,
      target_entity_id: target_entity,
      gateway_ip: Random.ipv4(),
      target_ip: Random.ipv4()
    }
  end

  @doc """
  Opts:
    - gateway_id: Specify the gateway id.
    - target_id: Specify the target id.
    - gateway_entity_id: Specify the gateway entity id.
    - target_entity_id: Specify the target entity id.

  Note the generated process is fake (does not exist on DB).
  """
  def process_created(type, opts \\ [])
  def process_created(:single_server, opts) do
    gateway_id = Access.get(opts, :gateway_id, Server.ID.generate())
    gateway_entity = Access.get(opts, :gateway_entity_id, Entity.ID.generate())

    process_created(gateway_id, gateway_id, gateway_entity, gateway_entity)
  end
  def process_created(:multi_server, opts) do
    gateway_id = Access.get(opts, :gateway_id, Server.ID.generate())
    gateway_entity = Access.get(opts, :gateway_entity_id, Entity.ID.generate())

    target_id = Access.get(opts, :target_id, Server.ID.generate())
    target_entity = Access.get(opts, :target_entity_id, Entity.ID.generate())

    process_created(gateway_id, target_id, gateway_entity, target_entity)
  end

  ##############################################################################
  # Universe.Bank events
  ##############################################################################

  @doc """
  Accepts: (Token.id, BankAccount.t, Entity.id)
  """
  def bank_token_acquired(token_id, acc, entity_id) do
    %BankTokenAcquiredEvent{
      entity_id: entity_id,
      token_id: token_id,
      atm_id: acc.atm_id,
      account_number: acc.account_number
    }
  end

  @doc """
  Accepts: (BankAccount.t, Entity.id)
  - password: Set event password. If not set, use the same one on the account
  """
  def bank_account_password_revealed(account, entity_id, opts \\ []) do
    password = Access.get(opts, :password, account.password)
    %BankAccountPasswordRevealedEvent{
      entity_id: entity_id,
      account_number: account.account_number,
      atm_id: account.atm_id,
      password: password
    }
  end

  @doc """
  Accepts: (BankAccount.t, Entity.id)
  """
  def bank_account_login(account, entity_id, token_id \\ nil) do
    %BankAccountLoginEvent{
      entity_id: entity_id,
      account: account,
      token_id: token_id
    }
  end
end