defmodule Churchapp.Authorization.Checks do
  @moduledoc """
  Custom authorization checks for the application.
  """

  defmodule HasRole do
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(opts) do
      "user has role #{inspect(opts[:role])}"
    end

    @impl true
    def match?(%{role: user_role}, _context, opts) do
      allowed_roles = List.wrap(opts[:role])
      user_role in allowed_roles
    end

    def match?(_, _, _), do: false
  end

  defmodule HasPermission do
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(opts) do
      "user has permission #{inspect(opts[:permission])}"
    end

    @impl true
    def match?(%{permissions: permissions}, _context, opts) when is_list(permissions) do
      required_permission = opts[:permission]
      required_permission in permissions
    end

    def match?(_, _, _), do: false
  end

  defmodule IsAdminOrAbove do
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(_opts) do
      "user is admin or super_admin"
    end

    @impl true
    def match?(%{role: role}, _context, _opts) do
      role in [:admin, :super_admin]
    end

    def match?(_, _, _), do: false
  end

  defmodule IsSuperAdmin do
    use Ash.Policy.SimpleCheck

    @impl true
    def describe(_opts) do
      "user is super_admin"
    end

    @impl true
    def match?(%{role: :super_admin}, _context, _opts), do: true
    def match?(_, _, _), do: false
  end
end
