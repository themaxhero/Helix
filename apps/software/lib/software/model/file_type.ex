defmodule Helix.Software.Model.FileType do

  use Ecto.Schema

  alias Helix.Software.Model.File, as: MdlFile, warn: false
  alias Helix.Software.Model.ModuleRole, as: MdlModuleRole, warn: false
  import Ecto.Changeset

  @type t :: %__MODULE__{
    file_type: String.t,
    extension: String.t
  }

  @creation_fields ~w/file_type extension/a

  @primary_key false
  schema "file_types" do
    field :file_type, :string,
      primary_key: true

    field :extension, :string
  end

  @spec create_changeset(%{file_type: String.t, extension: String.t}) :: Ecto.Changeset.t
  def create_changeset(params) do
    %__MODULE__{}
    |> cast(params, @creation_fields)
    |> validate_required(:file_type)
    |> unique_constraint(:file_type)
  end
end