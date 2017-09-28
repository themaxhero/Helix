defmodule Helix.Story.Event.EmailTest do

  use Helix.Test.Case.Integration

  alias Helix.Event.Notificable

  alias Helix.Test.Channel.Helper, as: ChannelHelper
  alias Helix.Test.Channel.Setup, as: ChannelSetup
  alias Helix.Test.Event.Setup, as: EventSetup
  alias Helix.Test.Story.Setup, as: StorySetup

  describe "Notificable.whom_to_notify/1" do
    test "notifies only the player" do
      {step, _} = StorySetup.step()

      event = EventSetup.story_email_sent(step, "emeiu_aidi")

      notification_list = Notificable.whom_to_notify(event)
      assert notification_list == [ChannelHelper.to_topic(step.entity_id)]
    end
  end

  describe "Notificable.generate_payload/2" do
    {step, _} = StorySetup.step()
    socket = ChannelSetup.mock_account_socket()

    email_id = "ceci n'est pas une emeiu"
    event = EventSetup.story_email_sent(step, email_id)

    assert {:ok, payload} = Notificable.generate_payload(event, socket)

    assert payload.event == "story_email_sent"
    assert payload.data.step == to_string(step.name)
    assert payload.data.email_id == email_id
    refute is_map(payload.data.timestamp)
  end
end
