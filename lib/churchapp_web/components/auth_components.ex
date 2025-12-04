defmodule ChurchappWeb.AuthComponents do
  @moduledoc """
  UI components for authorization and role-based rendering.
  """
  use Phoenix.Component
  import ChurchappWeb.LiveUserAuth

  @doc """
  Conditionally renders content based on user role.

  ## Examples

      <.authorized role={:admin} current_user={@current_user}>
        <button>Admin Only Button</button>
      </.authorized>

      <.authorized role={[:admin, :staff]} current_user={@current_user}>
        <p>Visible to admins and staff</p>
      </.authorized>
  """
  attr :role, :any, default: nil
  attr :permission, :atom, default: nil
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def authorized(assigns) do
    show? =
      cond do
        assigns.role -> has_role?(assigns.current_user, assigns.role)
        assigns.permission -> has_permission?(assigns.current_user, assigns.permission)
        true -> false
      end

    assigns = assign(assigns, :show?, show?)

    ~H"""
    <%= if @show? do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  Shows content if user can perform an action.

  ## Examples

      <.can action={:manage_contributions} current_user={@current_user}>
        <button phx-click="delete">Delete</button>
      </.can>
  """
  attr :action, :atom, required: true
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def can(assigns) do
    assigns = assign(assigns, :can?, can?(assigns.current_user, assigns.action))

    ~H"""
    <%= if @can? do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  Shows content if user is admin or super admin.

  ## Examples

      <.admin_only current_user={@current_user}>
        <.link navigate={~p"/admin"}>Admin Panel</.link>
      </.admin_only>
  """
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def admin_only(assigns) do
    assigns = assign(assigns, :is_admin?, is_admin?(assigns.current_user))

    ~H"""
    <%= if @is_admin? do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  Shows content if user is super admin only.

  ## Examples

      <.super_admin_only current_user={@current_user}>
        <button>Super Admin Action</button>
      </.super_admin_only>
  """
  attr :current_user, :map, required: true
  slot :inner_block, required: true

  def super_admin_only(assigns) do
    assigns = assign(assigns, :is_super_admin?, is_super_admin?(assigns.current_user))

    ~H"""
    <%= if @is_super_admin? do %>
      {render_slot(@inner_block)}
    <% end %>
    """
  end

  @doc """
  Displays a user's role badge.

  ## Examples

      <.role_badge role={@current_user.role} />
  """
  attr :role, :atom, required: true
  attr :class, :string, default: ""

  def role_badge(assigns) do
    badge_class =
      case assigns.role do
        :super_admin -> "bg-purple-600 text-white"
        :admin -> "bg-blue-600 text-white"
        :staff -> "bg-green-600 text-white"
        :leader -> "bg-yellow-600 text-white"
        :member -> "bg-gray-500 text-white"
        _ -> "bg-gray-400 text-white"
      end

    badge_text =
      assigns.role
      |> Atom.to_string()
      |> String.split("_")
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")

    assigns =
      assigns
      |> assign(:badge_class, badge_class)
      |> assign(:badge_text, badge_text)

    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
      @badge_class,
      @class
    ]}>
      {@badge_text}
    </span>
    """
  end
end
