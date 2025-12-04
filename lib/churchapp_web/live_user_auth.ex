defmodule ChurchappWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  import Phoenix.LiveView
  use ChurchappWeb, :verified_routes

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {ChurchappWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, _session, socket) do
    socket =
      if socket.assigns[:current_user] do
        socket
      else
        assign(socket, :current_user, nil)
      end

    {:cont, socket}
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: ~p"/sign-in")

      {:halt, socket}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, redirect(socket, to: ~p"/")}
    else
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  # Require admin role
  def on_mount(:require_admin, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.role in [:admin, :super_admin] do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You do not have permission to access this page.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  # Require specific role
  def on_mount({:require_role, role}, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && user.role == role do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You do not have permission to access this page.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  # Require specific permission
  def on_mount({:require_permission, permission}, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && permission in (user.permissions || []) do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You do not have permission to perform this action.")
        |> redirect(to: ~p"/")

      {:halt, socket}
    end
  end

  # Helper functions to use in LiveViews and templates

  @doc """
  Check if user has specific role(s).
  """
  def has_role?(user, role) when is_list(role) do
    user && user.role in role
  end

  def has_role?(user, role) do
    user && user.role == role
  end

  @doc """
  Check if user has specific permission.
  """
  def has_permission?(user, permission) do
    user && permission in (user.permissions || [])
  end

  @doc """
  Check if user can perform an action.
  """
  def can?(user, action, _resource \\ nil) do
    case {action, user && user.role} do
      {_, :super_admin} -> true
      {:manage_congregants, role} when role in [:admin, :staff] -> true
      {:view_congregants, role} when role in [:admin, :staff, :leader, :member] -> true
      {:manage_contributions, role} when role in [:admin, :staff] -> true
      {:view_contributions, role} when role in [:admin, :staff, :leader] -> true
      {:manage_ministries, role} when role in [:admin, :staff] -> true
      {:view_reports, role} when role in [:admin, :staff, :leader] -> true
      {:manage_users, :super_admin} -> true
      _ -> false
    end
  end

  @doc """
  Check if user is admin or super admin.
  """
  def is_admin?(user) do
    user && user.role in [:admin, :super_admin]
  end

  @doc """
  Check if user is super admin.
  """
  def is_super_admin?(user) do
    user && user.role == :super_admin
  end
end
