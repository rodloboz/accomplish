defmodule Accomplish.Career.JobApplication do
  @moduledoc false

  use Accomplish.Schema

  alias Accomplish.Accounts.User
  alias Accomplish.Career.Company

  @permitted ~w(role status applied_at last_updated_at source notes company_id applicant_id)a
  @required ~w(role status applied_at company_id applicant_id)a

  @status_types [:applied, :interviewing, :offer, :rejected]

  @derive {JSON.Encoder,
           only: [
             :id,
             :role,
             :status,
             :applied_at,
             :last_updated_at,
             :source,
             :notes,
             :company_id,
             :inserted_at,
             :updated_at
           ]}

  schema "job_applications" do
    field :role, :string
    field :status, Ecto.Enum, values: @status_types, default: :applied
    field :applied_at, :utc_datetime
    field :last_updated_at, :utc_datetime
    field :source, :string
    field :notes, :string

    belongs_to :company, Company
    belongs_to :applicant, User, foreign_key: :applicant_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(job_application, attrs) do
    job_application
    |> cast(attrs, @permitted)
    |> common_validations()
  end

  @doc false
  def create_changeset(company, applicant, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> put_assoc(:company, company)
    |> put_assoc(:applicant, applicant)
  end

  @doc false
  def update_changeset(job_application, attrs) do
    job_application |> changeset(attrs)
  end

  defp common_validations(changeset) do
    changeset
    |> validate_required(@required)
    |> assoc_constraint(:company)
    |> assoc_constraint(:applicant)
  end
end
