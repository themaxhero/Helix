defmodule Helix.Universe.Bank.Event.Handler.Bank.Account do

  import HELF.Flow

  alias Helix.Event
  alias Helix.Entity.Query.Entity, as: EntityQuery
  alias Helix.Universe.Bank.Action.Bank, as: BankAction
  alias Helix.Universe.Bank.Query.Bank, as: BankQuery

  alias Helix.Software.Event.Virus.Collected, as: VirusCollectedEvent
  alias Helix.Universe.Bank.Event.Bank.Account.Removed,
    as: BankAccountRemovedEvent
  alias Helix.Universe.Bank.Event.Bank.Account.Updated,
    as: BankAccountUpdatedEvent
  alias Helix.Universe.Bank.Event.AccountCreate.Processed,
    as: AccountCreateProcessedEvent
  alias Helix.Universe.Bank.Event.AccountClose.Processed,
    as: AccountCloseProcessedEvent
  alias Helix.Universe.Bank.Event.RevealPassword.Processed,
    as: RevealPasswordProcessedEvent
  alias Helix.Universe.Bank.Event.ChangePassword.Processed,
    as: ChangePasswordProcessedEvent
  alias Helix.Universe.Bank.Event.Bank.Account.Password.Changed,
    as: BankPasswordChangedEvent

  def account_create_processed(event = %AccountCreateProcessedEvent{}) do
    flowing do
      with \
        {:ok, _bank_account, events} <-
          BankAction.open_account(event.requester, event.atm_id),
        on_success(fn -> Event.emit(events, from: event) end)
      do
        :ok
      end
    end
  end

 def account_close_processed(event = %AccountCloseProcessedEvent{}) do
    flowing do
      with \
        bank_acc = BankQuery.fetch_account(event.atm_id, event.account_number),
        true <- not is_nil(bank_acc),
        {:ok, events} <- BankAction.close_account(bank_acc),
        on_success(fn -> Event.emit(events, from: event) end)
      do
        :ok
      end
    end
  end

  @doc """
  Handles the conclusion of a `PasswordRevealProcess`, described at
  `BankAccountFlow`. Note that actually *displaying* the password to the user
  only happens with the `BankAccountPasswordRevealedEvent`, since the conclusion
  of the `PasswordRevealProcess` does not imply that the password has been
  revealed (since the given input may be invalid).

  Emits: `BankAccountPasswordRevealedEvent`
  """
  def password_reveal_processed(event = %RevealPasswordProcessedEvent{}) do
    flowing do
      with \
        revealed_by = %{} <- EntityQuery.fetch_by_server(event.gateway_id),
        {:ok, _password, events} <-
          BankAction.reveal_password(
            event.account, event.token_id, revealed_by.entity_id
          ),
        on_success(fn -> Event.emit(events, from: event) end)
      do
        :ok
      end
    end
  end

  @doc """
  Handles the conclusion of a `PasswordChangeProcess`, described at
  `BankAccountFlow`

  Emits: `BankAccountPasswordChangedEvent`
  """
  def password_change_processed(event = %ChangePasswordProcessedEvent{}) do
    flowing do
      with \
           changed_by = %{} <- EntityQuery.fetch_by_server(event.gateway_id),
           {:ok, _bank_account, events} <-
           BankAction.change_password(event.account),
          on_success(fn -> Event.emit(events, from: event) end)
      do
        :ok
      end
    end
  end

  @doc """
  Emits BankAccountUpdatedEvent with reason :password to client update local
  information

  Emits: `BankAccountUpdatedEvent`
  """
  def password_changed(event = %BankPasswordChangedEvent{}) do
    account = event.account
    Event.emit(BankAccountUpdatedEvent.new(account, :password), from: event)
  end

  @doc """
  When the rewards of a virus have been successfully collected, it's time to
  update their bank account. That's what we do here.

  Notice that the event may be the result of a `miner_virus`, which rewards
  bitcoin as opposed to money, and as such we ignore if that's the case.

  Emits: `BankAccountUpdatedEvent`
  """
  def virus_collected(%VirusCollectedEvent{bank_account: nil}),
    do: :noop
  def virus_collected(event = %VirusCollectedEvent{}) do
    flowing do
      with \
        {:ok, _bank_account, events} <-
          BankAction.direct_deposit(event.bank_account, event.earnings),
        on_success(fn -> Event.emit(events, from: event) end)
      do
        :ok
      end
    end
  end
end
