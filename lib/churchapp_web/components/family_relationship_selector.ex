defmodule ChurchappWeb.FamilyRelationshipSelector do
  @moduledoc """
  A component for managing family relationships on congregant forms.

  Supports two modes:
  - Edit mode: For existing congregants - saves relationships immediately to DB
  - New mode: For new congregants - stores pending relationships until form submit
  """
  use Phoenix.LiveComponent
  use ChurchappWeb, :html

  require Ash.Query

  def update(assigns, socket) do
    actor = assigns[:actor]
    congregant_id = assigns[:congregant_id]
    mode = if congregant_id, do: :edit, else: :new

    # Load relationship types
    relationship_types = load_relationship_types(actor)

    # Load existing relationships (only in edit mode)
    relationships =
      if mode == :edit do
        load_relationships(congregant_id, actor)
      else
        assigns[:pending_relationships] || []
      end

    # Load congregants for selection (excluding current congregant)
    congregants = load_congregants(congregant_id, actor)

    socket =
      socket
      |> assign(:id, assigns[:id] || "family-relationship-selector")
      |> assign(:mode, mode)
      |> assign(:congregant_id, congregant_id)
      |> assign(:actor, actor)
      |> assign(:relationships, relationships)
      |> assign(:relationship_types, relationship_types)
      |> assign(:congregants, congregants)
      |> assign(:filtered_congregants, congregants)
      |> assign(:show_add_modal, false)
      |> assign(:selected_type, nil)
      |> assign(:search_query, "")
      |> assign(:step, 1)

    {:ok, socket}
  end

  defp load_relationship_types(actor) do
    case Chms.Church.list_active_family_relationship_types(actor: actor) do
      {:ok, types} -> types
      _ -> []
    end
  end

  defp load_relationships(congregant_id, actor) do
    case Chms.Church.FamilyRelationship
         |> Ash.Query.for_read(:read)
         |> Ash.Query.filter(congregant_id == ^congregant_id)
         |> Ash.Query.load([:related_congregant, :family_relationship_type])
         |> Ash.read(actor: actor) do
      {:ok, relationships} -> relationships
      _ -> []
    end
  end

  defp load_congregants(exclude_id, actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read)
      |> Ash.Query.sort(last_name: :asc, first_name: :asc)

    query =
      if exclude_id do
        Ash.Query.filter(query, id != ^exclude_id)
      else
        query
      end

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        Enum.map(congregants, fn c ->
          %{
            id: c.id,
            name: "#{c.first_name} #{c.last_name}",
            member_id: c.member_id
          }
        end)

      _ ->
        []
    end
  end

  # Event handlers
  def handle_event("open_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_modal, true)
     |> assign(:step, 1)
     |> assign(:selected_type, nil)
     |> assign(:search_query, "")
     |> assign(:filtered_congregants, socket.assigns.congregants)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, false)}
  end

  def handle_event("select_type", %{"id" => type_id}, socket) do
    type = Enum.find(socket.assigns.relationship_types, fn t -> t.id == type_id end)

    {:noreply,
     socket
     |> assign(:selected_type, type)
     |> assign(:step, 2)}
  end

  def handle_event("back_to_types", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, 1)
     |> assign(:selected_type, nil)
     |> assign(:search_query, "")
     |> assign(:filtered_congregants, socket.assigns.congregants)}
  end

  def handle_event("search_congregant", %{"query" => query}, socket) do
    filtered =
      if query == "" do
        socket.assigns.congregants
      else
        query_lower = String.downcase(query)

        Enum.filter(socket.assigns.congregants, fn c ->
          String.contains?(String.downcase(c.name), query_lower) ||
            String.contains?(to_string(c.member_id), query_lower)
        end)
      end

    {:noreply,
     socket
     |> assign(:search_query, query)
     |> assign(:filtered_congregants, filtered)}
  end

  def handle_event("select_congregant", %{"id" => related_congregant_id}, socket) do
    actor = socket.assigns.actor
    selected_type = socket.assigns.selected_type

    case socket.assigns.mode do
      :edit ->
        # Create relationship in database immediately
        attrs = %{
          congregant_id: socket.assigns.congregant_id,
          related_congregant_id: related_congregant_id,
          family_relationship_type_id: selected_type.id
        }

        case Chms.Church.create_family_relationship(attrs, actor: actor) do
          {:ok, _relationship} ->
            # Reload relationships
            relationships = load_relationships(socket.assigns.congregant_id, actor)

            {:noreply,
             socket
             |> assign(:relationships, relationships)
             |> assign(:show_add_modal, false)}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to add relationship")}
        end

      :new ->
        # Add to pending relationships (notify parent)
        related = Enum.find(socket.assigns.congregants, fn c -> c.id == related_congregant_id end)

        pending_relationship = %{
          temp_id: System.unique_integer([:positive]),
          related_congregant_id: related_congregant_id,
          related_congregant_name: related.name,
          family_relationship_type_id: selected_type.id,
          family_relationship_type_name: selected_type.display_name
        }

        new_relationships = socket.assigns.relationships ++ [pending_relationship]
        send(self(), {:family_relationships_changed, new_relationships})

        {:noreply,
         socket
         |> assign(:relationships, new_relationships)
         |> assign(:show_add_modal, false)}
    end
  end

  def handle_event("remove_relationship", %{"id" => id}, socket) do
    actor = socket.assigns.actor

    case socket.assigns.mode do
      :edit ->
        # Delete from database
        case Chms.Church.get_family_relationship_by_id(id, actor: actor) do
          {:ok, relationship} ->
            case Chms.Church.destroy_family_relationship(relationship, actor: actor) do
              :ok ->
                relationships = load_relationships(socket.assigns.congregant_id, actor)
                {:noreply, assign(socket, :relationships, relationships)}

              {:error, _} ->
                {:noreply, put_flash(socket, :error, "Failed to remove relationship")}
            end

          _ ->
            {:noreply, socket}
        end

      :new ->
        # Remove from pending
        temp_id = String.to_integer(id)
        new_relationships = Enum.reject(socket.assigns.relationships, &(&1.temp_id == temp_id))
        send(self(), {:family_relationships_changed, new_relationships})
        {:noreply, assign(socket, :relationships, new_relationships)}
    end
  end

  def render(assigns) do
    ~H"""
    <div id={@id}>
      <div class="space-y-4">
        <%!-- Header --%>
        <div class="flex items-center justify-between">
          <label class="block text-sm font-medium text-gray-300">
            Family Relationships
          </label>
          <button
            type="button"
            phx-click="open_add_modal"
            phx-target={@myself}
            class="inline-flex items-center px-3 py-1.5 text-xs font-medium text-primary-400 hover:text-primary-300 bg-primary-500/10 hover:bg-primary-500/20 rounded-md border border-primary-500/30 transition-colors"
          >
            <.icon name="hero-plus" class="mr-1 h-3 w-3" /> Add Relationship
          </button>
        </div>

        <%!-- Current Relationships --%>
        <div class="space-y-2">
          <%= if @relationships == [] do %>
            <div class="px-4 py-6 text-center text-gray-500 bg-dark-700/50 rounded-lg border border-dark-600 border-dashed">
              <.icon name="hero-users" class="h-8 w-8 mx-auto mb-2 text-gray-600" />
              <p class="text-sm">No family relationships added yet</p>
            </div>
          <% else %>
            <div class="flex flex-wrap gap-2">
              <%= for rel <- @relationships do %>
                <div class="inline-flex items-center gap-2 px-3 py-2 text-sm bg-dark-700 rounded-lg border border-dark-600">
                  <.icon name="hero-heart" class="h-4 w-4 text-primary-400" />
                  <span class="text-gray-300">
                    <span class="text-primary-400 font-medium">
                      {get_relationship_type_name(rel, @mode)}
                    </span>
                    <span class="text-gray-500 mx-1">of</span>
                    <span class="text-white">{get_related_name(rel, @mode)}</span>
                  </span>
                  <button
                    type="button"
                    phx-click="remove_relationship"
                    phx-value-id={get_relationship_id(rel, @mode)}
                    phx-target={@myself}
                    class="ml-1 text-gray-500 hover:text-red-400 transition-colors"
                  >
                    <.icon name="hero-x-mark" class="h-4 w-4" />
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Add Relationship Modal --%>
      <%= if @show_add_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div
              class="fixed inset-0 bg-dark-900/75 transition-opacity"
              phx-click="close_modal"
              phx-target={@myself}
            >
            </div>
            <span class="hidden sm:inline-block sm:align-middle sm:h-screen">&#8203;</span>
            <div class="inline-block align-bottom bg-dark-800 rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg sm:w-full border border-dark-700">
              <%!-- Modal Header --%>
              <div class="px-6 py-4 border-b border-dark-700 flex items-center justify-between">
                <div class="flex items-center gap-3">
                  <%= if @step == 2 do %>
                    <button
                      type="button"
                      phx-click="back_to_types"
                      phx-target={@myself}
                      class="p-1 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                    >
                      <.icon name="hero-arrow-left" class="h-5 w-5" />
                    </button>
                  <% end %>
                  <h3 class="text-lg font-medium text-white">
                    {if @step == 1, do: "Select Relationship Type", else: "Select Family Member"}
                  </h3>
                </div>
                <button
                  type="button"
                  phx-click="close_modal"
                  phx-target={@myself}
                  class="p-1 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>

              <%!-- Modal Content --%>
              <div class="px-6 py-4 max-h-96 overflow-y-auto">
                <%= if @step == 1 do %>
                  <%!-- Step 1: Select relationship type --%>
                  <%= if @relationship_types == [] do %>
                    <div class="py-8 text-center text-gray-500">
                      <.icon name="hero-exclamation-triangle" class="h-8 w-8 mx-auto mb-2 text-yellow-500" />
                      <p class="text-sm">No relationship types available.</p>
                      <p class="text-xs mt-1">Please add some in Admin → Family Relations.</p>
                    </div>
                  <% else %>
                    <div class="grid grid-cols-2 gap-3">
                      <%= for type <- @relationship_types do %>
                        <button
                          type="button"
                          phx-click="select_type"
                          phx-value-id={type.id}
                          phx-target={@myself}
                          class="flex items-center gap-3 p-3 text-left bg-dark-700/50 hover:bg-dark-700 rounded-lg border border-dark-600 hover:border-primary-500/50 transition-all"
                        >
                          <div class="flex-shrink-0 w-10 h-10 rounded-lg bg-primary-500/20 flex items-center justify-center">
                            <.icon name="hero-heart" class="w-5 h-5 text-primary-400" />
                          </div>
                          <div>
                            <div class="text-sm font-medium text-white">{type.display_name}</div>
                          </div>
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                <% else %>
                  <%!-- Step 2: Select congregant --%>
                  <div class="space-y-4">
                    <div class="text-sm text-gray-400 mb-4">
                      Adding as:
                      <span class="text-primary-400 font-medium">{@selected_type.display_name}</span>
                    </div>

                    <%!-- Search --%>
                    <form phx-change="search_congregant" phx-target={@myself}>
                      <div class="relative">
                        <.icon
                          name="hero-magnifying-glass"
                          class="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-500"
                        />
                        <input
                          type="text"
                          name="query"
                          placeholder="Search by name or member ID..."
                          value={@search_query}
                          phx-debounce="200"
                          class="w-full pl-10 pr-4 py-2 text-sm text-gray-200 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                        />
                      </div>
                    </form>

                    <%!-- Congregant List --%>
                    <div class="space-y-2 max-h-64 overflow-y-auto">
                      <%= if @filtered_congregants == [] do %>
                        <div class="py-4 text-center text-gray-500 text-sm">
                          No congregants found
                        </div>
                      <% else %>
                        <%= for congregant <- @filtered_congregants do %>
                          <button
                            type="button"
                            phx-click="select_congregant"
                            phx-value-id={congregant.id}
                            phx-target={@myself}
                            class="w-full flex items-center gap-3 p-3 text-left bg-dark-700/50 hover:bg-dark-700 rounded-lg border border-dark-600 hover:border-primary-500/50 transition-all"
                          >
                            <div class="flex-shrink-0 w-10 h-10 rounded-full bg-primary-500/20 flex items-center justify-center">
                              <span class="text-primary-400 font-medium text-sm">
                                {congregant.name |> String.first() |> String.upcase()}
                              </span>
                            </div>
                            <div class="flex-1 min-w-0">
                              <div class="text-sm font-medium text-white truncate">
                                {congregant.name}
                              </div>
                              <div class="text-xs text-gray-500">
                                ID: {congregant.member_id}
                              </div>
                            </div>
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions for rendering
  defp get_relationship_type_name(rel, :edit), do: rel.family_relationship_type.display_name
  defp get_relationship_type_name(rel, :new), do: rel.family_relationship_type_name

  defp get_related_name(rel, :edit),
    do: "#{rel.related_congregant.first_name} #{rel.related_congregant.last_name}"

  defp get_related_name(rel, :new), do: rel.related_congregant_name

  defp get_relationship_id(rel, :edit), do: rel.id
  defp get_relationship_id(rel, :new), do: to_string(rel.temp_id)
end
