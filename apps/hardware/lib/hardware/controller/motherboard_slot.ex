defmodule HELM.Hardware.Controller.MotherboardSlot do
  import Ecto.Query

  alias HELF.Broker
  alias HELM.Hardware.Repo
  alias HELM.Hardware.Model.MotherboardSlot, as: MdlMoboSlot

  def create(params) do
    MdlMoboSlot.create_changeset(params)
    |> do_create()
  end

  def find(slot_id) do
    case Repo.get_by(MdlMoboSlot, slot_id: slot_id) do
      nil -> {:error, :notfound}
      res -> {:ok, res}
    end
  end

  def link(slot_id, link_component_id) do
    with {:ok, slot} <- find(slot_id) do
      MdlMoboSlot.update_changeset(slot, %{link_component_id: link_component_id})
      |> Repo.update()
    else
      _ -> {:error, :notfound}
    end
  end

  def unlink(slot_id) do
    link(slot_id, nil)
  end

  def delete(slot_id) do
    MdlMoboSlot
    |> where([s], s.slot_id == ^slot_id)
    |> Repo.delete_all()

    :ok
  end

  defp do_create(changeset) do
    case Repo.insert(changeset) do
      {:ok, schema} ->
        Broker.cast("event:component:motherboard:slot:created", schema.slot_id)
        {:ok, schema}
      {:error, msg} ->
        {:error, msg}
    end
  end
end