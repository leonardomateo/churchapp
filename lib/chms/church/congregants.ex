defmodule Chms.Church.Congregants do
  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "congregants"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      argument :generated_member_id, :integer
      argument :ministries_string, :string

      accept [
        :first_name,
        :last_name,
        :address,
        :city,
        :state,
        :suite,
        :zip_code,
        :country,
        :mobile_tel,
        :home_tel,
        :work_tel,
        :dob,
        :member_since,
        :status,
        :is_leader,
        :image,
        :ministries
      ]

      change {Chms.Church.Congregants.Changes.AssignMemberId, []}
      change {Chms.Church.Congregants.Changes.ParseMinistries, []}
    end

    update :update do
      argument :ministries_string, :string

      accept [
        :first_name,
        :last_name,
        :address,
        :city,
        :state,
        :suite,
        :zip_code,
        :country,
        :mobile_tel,
        :home_tel,
        :work_tel,
        :dob,
        :member_since,
        :status,
        :is_leader,
        :image,
        :ministries
      ]

      change {Chms.Church.Congregants.Changes.ParseMinistries, []}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :member_id, :integer do
      constraints max: 9_999_999
      writable? false
      allow_nil? false
    end

    attribute :first_name, :string do
      allow_nil? false
    end

    attribute :last_name, :string do
      allow_nil? false
    end

    attribute :address, :string do
      allow_nil? false
    end

    attribute :city, :string do
      allow_nil? false
    end

    attribute :state, :string do
      allow_nil? false
    end

    attribute :suite, :string

    attribute :zip_code, :string do
      allow_nil? false
    end

    attribute :country, :string

    attribute :mobile_tel, :string do
      allow_nil? false
    end

    attribute :home_tel, :string
    attribute :work_tel, :string

    attribute :dob, :date

    attribute :member_since, :date do
      default &Date.utc_today/0
    end

    attribute :status, :atom do
      constraints one_of: [:member, :visitor, :honorific, :deceased]
      default :member
      allow_nil? false
    end

    attribute :is_leader, :boolean do
      default false
      allow_nil? false
    end

    attribute :image, :string

    attribute :ministries, {:array, :string}

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_member_id, [:member_id]
  end

  defmodule Changes.AssignMemberId do
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      member_id =
        case Ash.Changeset.fetch_argument(changeset, :generated_member_id) do
          {:ok, id} when not is_nil(id) -> id
          _ -> Enum.random(1_000_000..9_999_999)
        end

      Ash.Changeset.force_change_attribute(changeset, :member_id, member_id)
    end
  end

  defmodule Changes.ParseMinistries do
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      case Ash.Changeset.fetch_argument(changeset, :ministries_string) do
        {:ok, ministries_string} when is_binary(ministries_string) and ministries_string != "" ->
          ministries =
            ministries_string
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          Ash.Changeset.force_change_attribute(changeset, :ministries, ministries)

        _ ->
          # When no ministries_string provided or empty, set ministries to empty list
          Ash.Changeset.force_change_attribute(changeset, :ministries, [])
      end
    end

    # Implement atomic/3 to support atomic updates
    def atomic(changeset, _opts, _context) do
      case Ash.Changeset.fetch_argument(changeset, :ministries_string) do
        {:ok, ministries_string} when is_binary(ministries_string) and ministries_string != "" ->
          ministries =
            ministries_string
            |> String.split(",")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          {:atomic, %{ministries: {:atomic, ministries}}}

        _ ->
          # When no ministries_string provided or empty, set ministries to empty list
          {:atomic, %{ministries: {:atomic, []}}}
      end
    end
  end
end
