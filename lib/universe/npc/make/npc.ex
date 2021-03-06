defmodule Helix.Universe.NPC.Make.NPC do

  alias Helix.Universe.NPC.Model.NPC
  alias Helix.Universe.NPC.Action.NPC, as: NPCAction

  @spec story_char() ::
    {:ok, NPC.t, %{}}
  def story_char,
    do: create_npc(:story_char)

  @spec create_npc(NPC.type) ::
    {:ok, NPC.t, %{}}
  defp create_npc(type) do
    {:ok, npc} = NPCAction.create(type)

    {:ok, npc, %{}}
  end
end
