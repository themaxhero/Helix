defmodule Helix.Event.Dispatcher do
  @moduledoc false

  use HELF.Event

  alias Helix.Account
  alias Helix.Log
  alias Helix.Network
  alias Helix.Process
  alias Helix.Software
  alias Helix.Server

  ##############################################################################
  # Account events
  ##############################################################################
  event Account.Model.Account.AccountCreatedEvent,
    Account.Service.Event.Account,
    :account_create

  ##############################################################################
  # Log events
  ##############################################################################
  event Log.Model.Log.LogCreatedEvent,
    Server.Websocket.Channel.Server,
    :event_log_created

  event Log.Model.Log.LogModifiedEvent,
    Server.Websocket.Channel.Server,
    :event_log_modified

  event Log.Model.Log.LogDeletedEvent,
    Server.Websocket.Channel.Server,
    :event_log_deleted

  ##############################################################################
  # Network events
  ##############################################################################
  event Network.Model.ConnectionClosedEvent,
    Network.Service.Event.Tunnel,
    :connection_closed

  ##############################################################################
  # Process events
  ##############################################################################
  event Process.Model.Process.ProcessCreatedEvent,
    Process.Service.Event.TOP,
    :process_created
  event Process.Model.Process.ProcessCreatedEvent,
    Server.Websocket.Channel.Server,
    :event_process_created

  event Process.Model.Process.ProcessConclusionEvent,
    Server.Websocket.Channel.Server,
    :event_process_conclusion

  ##############################################################################
  # Software events
  ##############################################################################
  event Software.Model.SoftwareType.Encryptor.ProcessConclusionEvent,
    Software.Service.Event.Encryptor,
    :complete

  event Software.Model.SoftwareType.Decryptor.ProcessConclusionEvent,
    Software.Service.Event.Decryptor,
    :complete
end
