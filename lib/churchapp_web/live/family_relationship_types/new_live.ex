defmodule ChurchappWeb.FamilyRelationshipTypesLive.NewLive do
  use ChurchappWeb, :live_view

  alias AshPhoenix.Form

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    form =
      Chms.Church.FamilyRelationshipType
      |> Form.for_create(:create, domain: Chms.Church, actor: actor)
      |> to_form()

    # Get existing relationship types for inverse dropdown
    existing_types =
      case Chms.Church.list_family_relationship_types(actor: actor) do
        {:ok, types} -> types
        _ -> []
      end

    inverse_options =
      [{"None", ""}] ++
        Enum.map(existing_types, fn type -> {type.display_name, type.name} end)

    {:ok,
     socket
     |> assign(:page_title, "Add Relationship Type")
     |> assign(:form, form)
     |> assign(:inverse_options, inverse_options)
     |> assign(:saving, false)}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    socket = assign(socket, :saving, true)

    # Clean up inverse_name if empty
    params =
      if params["inverse_name"] == "" do
        Map.put(params, "inverse_name", nil)
      else
        params
      end

    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _type} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> put_flash(:info, "Relationship type created successfully")
         |> push_navigate(to: ~p"/admin/family-relationship-types")}

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:saving, false)
         |> assign(:form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <%!-- Back Navigation --%>
      <div class="mb-6">
        <.link
          navigate={~p"/admin/family-relationship-types"}
          class="flex items-center text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Relationship Types
        </.link>
      </div>

      <%!-- Header --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-8">
        <div class="px-6 py-8 border-b border-dark-700">
          <div class="flex items-center gap-6">
            <div class="flex-shrink-0 h-20 w-20 rounded-full bg-primary-500/20 flex items-center justify-center">
              <.icon name="hero-heart" class="h-10 w-10 text-primary-500" />
            </div>
            <div class="flex-1">
              <h1 class="text-2xl font-bold text-white mb-2">
                Add Relationship Type
              </h1>
              <p class="text-sm text-gray-400">
                Create a new family relationship type for linking congregants
              </p>
            </div>
          </div>
        </div>
      </div>

      <%!-- Form --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-8">
        <.form for={@form} phx-change="validate" phx-submit="save" id="relationship-type-form">
          <div class="p-6 space-y-6">
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  System Name <span class="text-red-500">*</span>
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="e.g., father"
                  class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors"
                />
                <p class="mt-1 text-xs text-gray-500">
                  Unique identifier, lowercase, no spaces
                </p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Display Name <span class="text-red-500">*</span>
                </label>
                <.input
                  field={@form[:display_name]}
                  type="text"
                  placeholder="e.g., Father"
                  class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors"
                />
                <p class="mt-1 text-xs text-gray-500">
                  User-friendly name shown in the UI
                </p>
              </div>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Inverse Relationship
                </label>
                <.input
                  field={@form[:inverse_name]}
                  type="select"
                  options={@inverse_options}
                  class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors cursor-pointer"
                />
                <p class="mt-1 text-xs text-gray-500">
                  The reverse relationship (e.g., "child" is inverse of "father")
                </p>
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Sort Order
                </label>
                <.input
                  field={@form[:sort_order]}
                  type="number"
                  placeholder="0"
                  class="w-full px-4 py-3 text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent transition-colors"
                />
                <p class="mt-1 text-xs text-gray-500">
                  Order in dropdown lists (lower numbers appear first)
                </p>
              </div>
            </div>

            <div>
              <label class="flex items-center gap-3 cursor-pointer">
                <.input
                  field={@form[:is_active]}
                  type="checkbox"
                  class="w-5 h-5 rounded border-dark-600 bg-dark-700 text-primary-500 focus:ring-primary-500 focus:ring-offset-dark-800"
                />
                <div>
                  <span class="text-sm font-medium text-gray-300">Active</span>
                  <p class="text-xs text-gray-500">
                    Inactive types won't appear in selection dropdowns
                  </p>
                </div>
              </label>
            </div>
          </div>

          <%!-- Actions --%>
          <div class="px-6 py-4 bg-dark-700/50 border-t border-dark-700 flex justify-end gap-4">
            <.link
              navigate={~p"/admin/family-relationship-types"}
              class="px-6 py-3 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              disabled={@saving}
              class={[
                "px-6 py-3 text-sm font-medium text-white rounded-md shadow-lg transition-colors",
                if(@saving,
                  do: "bg-primary-600 cursor-not-allowed opacity-50",
                  else: "bg-primary-500 hover:bg-primary-600 shadow-primary-500/20"
                )
              ]}
            >
              <%= if @saving do %>
                <span class="flex items-center gap-2">
                  <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" /> Creating...
                </span>
              <% else %>
                Create Type
              <% end %>
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
