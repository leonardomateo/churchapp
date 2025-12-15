defmodule Chms.Church.AttendanceCategories do
  @moduledoc """
  Ash resource for managing attendance categories.
  Categories can be system (predefined) or custom (added by users).
  System categories include: Services, Youth Class, Men Class, Women Class, Nursery Class, Baptism Class.
  """

  use Ash.Resource,
    otp_app: :churchapp,
    domain: Chms.Church,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Churchapp.Authorization.Checks

  postgres do
    table "attendance_categories"
    repo Churchapp.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :color,
        :active,
        :is_system,
        :display_order
      ]

      change fn changeset, _context ->
        # Set default display_order based on existing categories
        case Ash.Changeset.get_attribute(changeset, :display_order) do
          nil ->
            # Get next available display_order
            next_order = get_next_display_order()
            Ash.Changeset.force_change_attribute(changeset, :display_order, next_order)

          _ ->
            changeset
        end
      end
    end

    update :update do
      accept [
        :name,
        :description,
        :color,
        :active,
        :display_order
      ]
    end

    update :deactivate do
      require_atomic? false
      accept []

      validate fn changeset, _context ->
        is_system = Ash.Changeset.get_data(changeset, :is_system)

        if is_system do
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :is_active,
             message: "Cannot deactivate system categories"
           )}
        else
          :ok
        end
      end

      change set_attribute(:active, false)
    end

    read :list_active do
      prepare build(sort: [display_order: :asc])
      filter expr(active == true)
    end
  end

  policies do
    # Super admins bypass all policies
    bypass action_type([:create, :read, :update, :destroy]) do
      authorize_if {Checks.IsSuperAdmin, []}
    end

    # Read policy - all authenticated users can view categories
    policy action_type(:read) do
      authorize_if {Checks.HasRole, role: [:admin, :staff, :leader, :member]}
    end

    # Write policies - only admins and staff can manage categories
    policy action_type([:create, :update]) do
      authorize_if {Checks.HasRole, role: [:admin, :staff]}
    end

    # Destroy policy - only admins can delete, and only non-system categories
    policy action_type(:destroy) do
      authorize_if {Checks.HasRole, role: [:admin]}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      description "Category name (e.g., 'Services', 'Youth Class')"
    end

    attribute :description, :string do
      allow_nil? true
      description "Optional description of the category"
    end

    attribute :color, :string do
      allow_nil? false
      default "#06b6d4"
      description "Hex color code for display (e.g., '#06b6d4')"
    end

    attribute :active, :boolean do
      allow_nil? false
      default true
      description "Whether the category is active and available for use"
    end

    attribute :is_system, :boolean do
      allow_nil? false
      default false
      description "True for predefined categories that cannot be deleted"
    end

    attribute :display_order, :integer do
      allow_nil? false
      default 0
      description "Order for displaying categories (lower numbers first)"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :attendance_sessions, Chms.Church.AttendanceSessions do
      destination_attribute :category_id
    end
  end

  identities do
    identity :unique_name, [:name]
  end

  defp get_next_display_order do
    try do
      all_categories = Ash.read!(__MODULE__)
      max_order = all_categories |> Enum.map(& &1.display_order) |> Enum.max(fn -> 0 end)
      max_order + 1
    rescue
      _ -> 1
    end
  end

  @doc """
  Returns the list of default system categories to be seeded.
  """
  def default_categories do
    [
      %{
        name: "Services",
        color: "#06b6d4",
        description: "General church services (any day)",
        is_system: true,
        display_order: 1
      },
      %{
        name: "Youth Class",
        color: "#8b5cf6",
        description: "Youth ministry classes",
        is_system: true,
        display_order: 2
      },
      %{
        name: "Men Class",
        color: "#3b82f6",
        description: "Men's ministry classes",
        is_system: true,
        display_order: 3
      },
      %{
        name: "Women Class",
        color: "#ec4899",
        description: "Women's ministry classes",
        is_system: true,
        display_order: 4
      },
      %{
        name: "Nursery Class",
        color: "#f59e0b",
        description: "Nursery and toddler care",
        is_system: true,
        display_order: 5
      },
      %{
        name: "Baptism Class",
        color: "#10b981",
        description: "Baptism preparation classes",
        is_system: true,
        display_order: 6
      }
    ]
  end

  @doc """
  Returns the icon name for the category based on name.
  """
  def category_icon("Services"), do: "hero-building-library"
  def category_icon("Youth Class"), do: "hero-academic-cap"
  def category_icon("Men Class"), do: "hero-user-group"
  def category_icon("Women Class"), do: "hero-user-group"
  def category_icon("Nursery Class"), do: "hero-heart"
  def category_icon("Baptism Class"), do: "hero-sparkles"
  def category_icon(_), do: "hero-clipboard-document-list"
end
