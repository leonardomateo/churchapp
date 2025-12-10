defmodule ChurchappWeb.MinistrySelector do
  @moduledoc """
  A searchable dropdown selector for ministries.
  Supports two modes:
  - Single-select mode (for Ministry Funds): Uses `form`, `field`, and `ministries`
  - Multi-select mode (for Congregants): Uses `ministries` and `selected`
  """
  use Phoenix.LiveComponent
  use ChurchappWeb, :html

  # Multi-select mode (for Congregants) - uses `selected` assign
  def update(%{ministries: ministries, selected: selected} = assigns, socket) when is_list(selected) do
    socket =
      socket
      |> assign(:id, assigns[:id] || "ministry-selector")
      |> assign(:name, assigns[:name] || "form[ministries][]")
      |> assign(:mode, :multi)
      |> assign(:all_ministries, ministries)
      |> assign(:selected_ministries, selected)
      |> assign(:selected_value, nil)
      |> assign(:field, nil)
      |> assign(:query, "")
      |> assign(:filtered_ministries, filter_unselected(ministries, selected))
      |> assign(:show_dropdown, false)
      |> assign(:focused_index, -1)

    {:ok, socket}
  end

  # Single-select mode (for Ministry Funds) - uses `form` and `field` assigns
  def update(%{ministries: ministries, field: field} = assigns, socket) do
    current_value = field.value || ""

    socket =
      socket
      |> assign(:id, assigns[:id] || "ministry-selector")
      |> assign(:name, field.name)
      |> assign(:mode, :single)
      |> assign(:all_ministries, ministries)
      |> assign(:selected_ministries, [])
      |> assign(:selected_value, current_value)
      |> assign(:field, field)
      |> assign(:query, current_value)
      |> assign(:filtered_ministries, search_single(ministries, ""))
      |> assign(:show_dropdown, false)
      |> assign(:focused_index, -1)

    {:ok, socket}
  end

  def handle_event("show_dropdown", _params, socket) do
    filtered =
      case socket.assigns.mode do
        :multi -> filter_unselected(socket.assigns.all_ministries, socket.assigns.selected_ministries)
        :single -> search_single(socket.assigns.all_ministries, socket.assigns.query || "")
      end

    {:noreply,
     socket
     |> assign(:show_dropdown, true)
     |> assign(:focused_index, -1)
     |> assign(:filtered_ministries, filtered)}
  end

  def handle_event("hide_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle keyboard navigation
  def handle_event("handle_key", %{"key" => "ArrowDown"}, socket) do
    if socket.assigns.show_dropdown do
      current_index = socket.assigns.focused_index
      new_index = min(current_index + 1, length(socket.assigns.filtered_ministries) - 1)
      {:noreply, assign(socket, :focused_index, new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "ArrowUp"}, socket) do
    if socket.assigns.show_dropdown do
      new_index = max(socket.assigns.focused_index - 1, -1)
      {:noreply, assign(socket, :focused_index, new_index)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Enter"}, socket) do
    if socket.assigns.show_dropdown and socket.assigns.focused_index >= 0 and
         length(socket.assigns.filtered_ministries) > 0 do
      {name, _value} = Enum.at(socket.assigns.filtered_ministries, socket.assigns.focused_index)
      select_ministry(socket, name)
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_key", %{"key" => "Escape"}, socket) do
    {:noreply, assign(socket, :show_dropdown, false)}
  end

  # Handle typing for search
  def handle_event("handle_key", %{"value" => query}, socket) do
    filtered =
      case socket.assigns.mode do
        :multi -> search_ministries(socket.assigns.all_ministries, socket.assigns.selected_ministries, query)
        :single -> search_single(socket.assigns.all_ministries, query)
      end

    focused_index = if length(filtered) > 0, do: 0, else: -1

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:filtered_ministries, filtered)
     |> assign(:focused_index, focused_index)
     |> assign(:show_dropdown, true)}
  end

  def handle_event("select_ministry", %{"name" => name}, socket) do
    select_ministry(socket, name)
  end

  def handle_event("remove_ministry", %{"name" => name}, socket) do
    new_selected = Enum.reject(socket.assigns.selected_ministries, &(&1 == name))
    filtered = filter_unselected(socket.assigns.all_ministries, new_selected)
    send(self(), {:ministries_changed, new_selected})

    {:noreply,
     socket
     |> assign(:selected_ministries, new_selected)
     |> assign(:filtered_ministries, filtered)}
  end

  def handle_event("clear_all", _params, socket) do
    send(self(), {:ministries_changed, []})

    {:noreply,
     socket
     |> assign(:selected_ministries, [])
     |> assign(:filtered_ministries, socket.assigns.all_ministries)
     |> assign(:query, "")}
  end

  defp select_ministry(socket, name) do
    case socket.assigns.mode do
      :single ->
        # Single-select mode: select one ministry and update the form field
        if socket.assigns.field do
          Phoenix.LiveView.JS.push("change", to: "##{socket.assigns.field.form.id}", value: %{socket.assigns.field.name => name})
        end

        {:noreply,
         socket
         |> assign(:selected_value, name)
         |> assign(:query, name)
         |> assign(:show_dropdown, false)}

      :multi ->
        # Multi-select mode: add to selected list
        if name in socket.assigns.selected_ministries do
          {:noreply, socket}
        else
          new_selected = socket.assigns.selected_ministries ++ [name]
          filtered = filter_unselected(socket.assigns.all_ministries, new_selected)
          send(self(), {:ministries_changed, new_selected})

          {:noreply,
           socket
           |> assign(:selected_ministries, new_selected)
           |> assign(:filtered_ministries, filtered)
           |> assign(:query, "")
           |> assign(:show_dropdown, false)}
        end
    end
  end

  defp filter_unselected(all_ministries, selected) do
    Enum.reject(all_ministries, fn {name, _value} -> name in selected end)
  end

  defp search_single(all_ministries, query) when query == "" or is_nil(query) do
    all_ministries
  end

  defp search_single(all_ministries, query) do
    query_lower = String.downcase(query)

    Enum.filter(all_ministries, fn {name, _value} ->
      String.contains?(String.downcase(name), query_lower)
    end)
  end

  defp search_ministries(all_ministries, selected, query) when query == "" or is_nil(query) do
    filter_unselected(all_ministries, selected)
  end

  defp search_ministries(all_ministries, selected, query) do
    query_lower = String.downcase(query)

    all_ministries
    |> Enum.reject(fn {name, _value} -> name in selected end)
    |> Enum.filter(fn {name, _value} ->
      String.contains?(String.downcase(name), query_lower)
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="relative" id={@id}>
      <%= if @mode == :single do %>
        <%!-- Single-select mode: hidden input with selected value --%>
        <input type="hidden" name={@name} value={@selected_value || ""} />

        <%!-- Search input for single select --%>
        <div class="relative">
          <input
            type="text"
            id={"#{@id}-input"}
            value={@query}
            phx-focus="show_dropdown"
            phx-keyup="handle_key"
            phx-target={@myself}
            phx-debounce="150"
            autocomplete="off"
            placeholder="Search or select a ministry..."
            class="block w-full px-3 py-2 pr-10 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500 cursor-pointer"
          />
          <.icon
            name="hero-chevron-down"
            class="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none"
          />
        </div>
      <% else %>
        <%!-- Multi-select mode: hidden inputs for each selected ministry --%>
        <input type="hidden" name={@name} value="" />
        <input :for={ministry <- @selected_ministries} type="hidden" name={@name} value={ministry} />

        <%!-- Search input for multi-select --%>
        <div class="relative">
          <input
            type="text"
            id={"#{@id}-input"}
            value={@query}
            phx-focus="show_dropdown"
            phx-keyup="handle_key"
            phx-target={@myself}
            phx-debounce="150"
            autocomplete="off"
            placeholder="Search ministries to add..."
            class="block w-full px-3 py-2 pr-10 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500 cursor-pointer"
          />
          <.icon
            name="hero-magnifying-glass"
            class="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400 pointer-events-none"
          />
        </div>
      <% end %>

      <%!-- Dropdown --%>
      <div
        :if={@show_dropdown}
        class="absolute z-50 w-full mt-1 bg-dark-800 border border-dark-700 rounded-md shadow-lg max-h-60 overflow-auto"
        id={"#{@id}-dropdown"}
        phx-click-away="hide_dropdown"
        phx-target={@myself}
      >
        <div :if={@filtered_ministries == []} class="px-3 py-2 text-gray-400 text-sm">
          <%= if @query != "" do %>
            No ministries found matching "{@query}"
          <% else %>
            <%= if @mode == :single, do: "No ministries available", else: "All ministries selected" %>
          <% end %>
        </div>

        <div
          :for={{{name, _value}, index} <- Enum.with_index(@filtered_ministries)}
          class={[
            "px-3 py-2 cursor-pointer text-sm border-b border-dark-700 last:border-b-0 transition-colors",
            index == @focused_index && "bg-primary-500 text-white",
            index != @focused_index && "text-gray-300 hover:bg-dark-700"
          ]}
          phx-click="select_ministry"
          phx-value-name={name}
          phx-target={@myself}
        >
          <div class="flex items-center justify-between">
            <div class="font-medium">{name}</div>
            <%= if index == @focused_index do %>
              <.icon name="hero-check" class="h-4 w-4" />
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
