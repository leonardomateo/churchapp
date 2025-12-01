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
        :image
      ]

      change {Chms.Church.Congregants.Changes.AssignMemberId, []}
    end

    update :update do
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
        :image
      ]
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
end
