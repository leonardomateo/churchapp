defmodule Chms.Church.ReportCategories do
  @moduledoc """
  Ash resource for managing report category definitions.
  Categories can be default (predefined) or custom (added by admins).
  Used by Week Ending Reports to define what categories can be tracked.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "report_categories"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :display_name,
        :group,
        :sort_order,
        :is_default,
        :is_active
      ]

      change fn changeset, _context ->
        # Generate name from display_name if not provided
        case Ash.Changeset.get_attribute(changeset, :name) do
          nil ->
            display_name = Ash.Changeset.get_attribute(changeset, :display_name)

            if display_name do
              name =
                display_name
                |> String.downcase()
                |> String.replace(~r/[^a-z0-9]+/, "_")
                |> String.trim("_")

              Ash.Changeset.force_change_attribute(changeset, :name, name)
            else
              changeset
            end

          _ ->
            changeset
        end
      end
    end

    update :update do
      accept [
        :display_name,
        :group,
        :sort_order,
        :is_active
      ]
    end

    update :deactivate do
      require_atomic? false
      accept []

      validate fn changeset, _context ->
        category_id = Ash.Changeset.get_data(changeset, :id)

        # Check if category is used in any reports
        case check_category_usage(category_id) do
          {:ok, 0} ->
            :ok

          {:ok, count} ->
            {:error,
             Ash.Error.Changes.InvalidAttribute.exception(
               field: :is_active,
               message: "Cannot deactivate category that is used in #{count} report(s)"
             )}

          {:error, _} ->
            :ok
        end
      end

      change set_attribute(:is_active, false)
    end

    read :list_active do
      filter expr(is_active == true)
    end

    read :list_by_group do
      argument :group, :atom do
        allow_nil? false
        constraints one_of: [:offerings, :ministries, :missions, :property, :custom]
      end

      filter expr(is_active == true and group == ^arg(:group))
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - admins and staff can view categories
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
    end

    # Write policies - only admins can manage categories
    policy action_type([:create, :update, :destroy]) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Unique identifier name (e.g., 'tithes', 'sunday_school')"
    end

    attribute :display_name, :string do
      allow_nil? false
      description "Human-readable name (e.g., 'Tithes', 'Sunday School')"
    end

    attribute :group, :atom do
      constraints one_of: [:offerings, :ministries, :missions, :property, :custom]
      allow_nil? false
      default :custom
      description "Category group for organizing in the form"
    end

    attribute :sort_order, :integer do
      allow_nil? false
      default 0
      description "Order within the group (lower numbers first)"
    end

    attribute :is_default, :boolean do
      allow_nil? false
      default false
      description "True for the 20 predefined categories"
    end

    attribute :is_active, :boolean do
      allow_nil? false
      default true
      description "Soft delete - inactive categories are hidden but preserved"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :category_entries, Chms.Church.ReportCategoryEntries do
      destination_attribute :report_category_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end

  defp check_category_usage(category_id) do
    try do
      all_entries = Ash.read!(Chms.Church.ReportCategoryEntries)

      count =
        all_entries
        |> Enum.filter(fn entry -> entry.report_category_id == category_id end)
        |> length()

      {:ok, count}
    rescue
      _ -> {:error, :query_failed}
    end
  end

  @doc """
  Returns the list of default categories to be seeded.
  """
  def default_categories do
    [
      # Offerings
      %{
        name: "tithes",
        display_name: "Tithes",
        group: :offerings,
        sort_order: 1,
        is_default: true
      },
      %{
        name: "sunday_school",
        display_name: "Sunday School",
        group: :offerings,
        sort_order: 2,
        is_default: true
      },
      %{
        name: "sunday_school_books",
        display_name: "Sunday School Books",
        group: :offerings,
        sort_order: 3,
        is_default: true
      },

      # Ministries
      %{
        name: "benevolence_ministry",
        display_name: "Benevolence Ministry",
        group: :ministries,
        sort_order: 1,
        is_default: true
      },
      %{
        name: "men_ministry",
        display_name: "Men Ministry",
        group: :ministries,
        sort_order: 2,
        is_default: true
      },
      %{
        name: "kitchen_ministry",
        display_name: "Kitchen Ministry",
        group: :ministries,
        sort_order: 3,
        is_default: true
      },
      %{
        name: "children_ministry",
        display_name: "Children Ministry",
        group: :ministries,
        sort_order: 4,
        is_default: true
      },
      %{
        name: "women_ministry",
        display_name: "Women Ministry",
        group: :ministries,
        sort_order: 5,
        is_default: true
      },
      %{
        name: "evangelism_ministry",
        display_name: "Evangelism Ministry",
        group: :ministries,
        sort_order: 6,
        is_default: true
      },
      %{
        name: "girls_ministry",
        display_name: "Girls Ministry",
        group: :ministries,
        sort_order: 7,
        is_default: true
      },
      %{
        name: "youth_ministry",
        display_name: "Youth Ministry",
        group: :ministries,
        sort_order: 8,
        is_default: true
      },
      %{
        name: "pro_templo_ministry",
        display_name: "Pro-Templo Ministry",
        group: :ministries,
        sort_order: 9,
        is_default: true
      },
      %{
        name: "royal_rangers_ministry",
        display_name: "Royal Rangers Ministry",
        group: :ministries,
        sort_order: 10,
        is_default: true
      },
      %{
        name: "ushers_ministry",
        display_name: "Ushers Ministry",
        group: :ministries,
        sort_order: 11,
        is_default: true
      },

      # Missions
      %{
        name: "missions",
        display_name: "Missions",
        group: :missions,
        sort_order: 1,
        is_default: true
      },

      # Property
      %{name: "venue", display_name: "Venue", group: :property, sort_order: 1, is_default: true},
      %{
        name: "rent_313_1",
        display_name: "Rent 313-1",
        group: :property,
        sort_order: 2,
        is_default: true
      },
      %{
        name: "rent_313_2",
        display_name: "Rent 313-2",
        group: :property,
        sort_order: 3,
        is_default: true
      },
      %{
        name: "rent_313_3",
        display_name: "Rent 313-3",
        group: :property,
        sort_order: 4,
        is_default: true
      },
      %{
        name: "rent_316_1",
        display_name: "Rent 316-1",
        group: :property,
        sort_order: 5,
        is_default: true
      }
    ]
  end

  @doc """
  Returns the display name for a group atom.
  """
  def group_display_name(:offerings), do: "Offerings"
  def group_display_name(:ministries), do: "Ministries"
  def group_display_name(:missions), do: "Missions"
  def group_display_name(:property), do: "Property & Rentals"
  def group_display_name(:custom), do: "Custom Categories"
  def group_display_name(_), do: "Other"

  @doc """
  Returns the icon name for a group.
  """
  def group_icon(:offerings), do: "hero-currency-dollar"
  def group_icon(:ministries), do: "hero-building-library"
  def group_icon(:missions), do: "hero-globe-alt"
  def group_icon(:property), do: "hero-home-modern"
  def group_icon(:custom), do: "hero-plus-circle"
  def group_icon(_), do: "hero-folder"

  @doc """
  Returns all groups in display order.
  """
  def groups_in_order do
    [:offerings, :ministries, :missions, :property, :custom]
  end
end
