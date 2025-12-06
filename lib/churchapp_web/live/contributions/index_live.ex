defmodule ChurchappWeb.ContributionsLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Contributions")
      |> assign(:search_query, "")
      |> assign(:type_filter, "")
      |> assign(:date_from, "")
      |> assign(:date_to, "")
      |> assign(:amount_min, "")
      |> assign(:amount_max, "")
      |> assign(:show_advanced_filters, false)
      |> assign(:open_menu_id, nil)
      |> assign(:delete_single_id, nil)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:show_delete_confirm, false)
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> fetch_contributions()

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket
    |> assign(:search_query, query)
    |> assign(:page, 1)
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    socket
    |> assign(:type_filter, type)
    |> assign(:page, 1)
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_date", %{"date_from" => date_from, "date_to" => date_to}, socket) do
    socket
    |> assign(:date_from, date_from)
    |> assign(:date_to, date_to)
    |> assign(:page, 1)
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event(
        "filter_amount",
        %{"amount_min" => amount_min, "amount_max" => amount_max},
        socket
      ) do
    socket
    |> assign(:amount_min, amount_min)
    |> assign(:amount_max, amount_max)
    |> assign(:page, 1)
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event("toggle_advanced_filters", _params, socket) do
    {:noreply, assign(socket, :show_advanced_filters, !socket.assigns.show_advanced_filters)}
  end

  def handle_event("clear_filters", _params, socket) do
    socket
    |> assign(:search_query, "")
    |> assign(:type_filter, "")
    |> assign(:date_from, "")
    |> assign(:date_to, "")
    |> assign(:amount_min, "")
    |> assign(:amount_max, "")
    |> assign(:page, 1)
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    socket
    |> assign(:page, String.to_integer(page))
    |> assign(:selected_ids, MapSet.new())
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_ids = socket.assigns.selected_ids

    new_selected_ids =
      if MapSet.member?(selected_ids, id) do
        MapSet.delete(selected_ids, id)
      else
        MapSet.put(selected_ids, id)
      end

    {:noreply, assign(socket, :selected_ids, new_selected_ids)}
  end

  def handle_event("toggle_select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.contributions, & &1.id) |> MapSet.new()

    new_selected_ids =
      if MapSet.equal?(socket.assigns.selected_ids, all_ids) do
        MapSet.new()
      else
        all_ids
      end

    {:noreply, assign(socket, :selected_ids, new_selected_ids)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  def handle_event("show_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :show_delete_confirm, false)}
  end

  def handle_event("confirm_delete_selected", _params, socket) do
    actor = socket.assigns.current_user
    count = MapSet.size(socket.assigns.selected_ids)

    Enum.each(socket.assigns.selected_ids, fn id ->
      case Ash.get(Chms.Church.Contributions, id, actor: actor) do
        {:ok, contribution} -> Ash.destroy(contribution, actor: actor)
        _ -> :ok
      end
    end)

    socket
    |> put_flash(:info, "Successfully deleted #{count} contribution(s)")
    |> assign(:selected_ids, MapSet.new())
    |> assign(:show_delete_confirm, false)
    |> fetch_contributions()
    |> then(&{:noreply, &1})
  end

  def handle_event("toggle_menu", %{"id" => id}, socket) do
    new_menu_id = if socket.assigns.open_menu_id == id, do: nil, else: id
    {:noreply, assign(socket, :open_menu_id, new_menu_id)}
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, :open_menu_id, nil)}
  end

  def handle_event("show_delete_single", %{"id" => id}, socket) do
    {:noreply, assign(socket, delete_single_id: id, open_menu_id: nil)}
  end

  def handle_event("cancel_delete_single", _params, socket) do
    {:noreply, assign(socket, :delete_single_id, nil)}
  end

  def handle_event("confirm_delete_single", _params, socket) do
    actor = socket.assigns.current_user

    contribution =
      Ash.get!(Chms.Church.Contributions, socket.assigns.delete_single_id, actor: actor)

    case Ash.destroy(contribution, actor: actor) do
      :ok ->
        socket
        |> put_flash(:info, "Contribution deleted successfully")
        |> assign(:delete_single_id, nil)
        |> fetch_contributions()
        |> then(&{:noreply, &1})

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete contribution")
         |> assign(:delete_single_id, nil)}
    end
  end

  defp fetch_contributions(socket) do
    actor = socket.assigns[:current_user]

    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.load([:congregant])
      |> Ash.Query.sort(contribution_date: :desc)

    query =
      if socket.assigns.search_query != "" do
        search_term = String.downcase(socket.assigns.search_query)
        # Split into parts for full name search
        parts = String.split(search_term, " ", trim: true)

        case parts do
          [] ->
            # Empty search after trimming
            query

          [single_word] ->
            # Single word search - search in all fields
            Ash.Query.filter(
              query,
              contains(string_downcase(contribution_type), ^single_word) or
                contains(string_downcase(congregant.first_name), ^single_word) or
                contains(string_downcase(congregant.last_name), ^single_word)
            )

          [first_part, last_part] ->
            # Search for "first last" pattern
            Ash.Query.filter(
              query,
              (contains(string_downcase(congregant.first_name), ^first_part) and
                 contains(string_downcase(congregant.last_name), ^last_part)) or
                contains(string_downcase(contribution_type), ^first_part) or
                contains(string_downcase(contribution_type), ^last_part)
            )

          _ ->
            # Multiple words - search each word in any field
            trimmed_term = String.trim(search_term)

            Ash.Query.filter(
              query,
              contains(string_downcase(contribution_type), ^trimmed_term) or
                contains(string_downcase(congregant.first_name), ^trimmed_term) or
                contains(string_downcase(congregant.last_name), ^trimmed_term)
            )
        end
      else
        query
      end

    query =
      if socket.assigns.type_filter != "" do
        Ash.Query.filter(query, contribution_type == ^socket.assigns.type_filter)
      else
        query
      end

    # Filter by date range
    query =
      if socket.assigns.date_from != "" and socket.assigns.date_from != nil do
        case Date.from_iso8601(socket.assigns.date_from) do
          {:ok, date} ->
            # Convert date to datetime at start of day (00:00:00)
            datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
            Ash.Query.filter(query, contribution_date >= ^datetime)

          _ ->
            query
        end
      else
        query
      end

    query =
      if socket.assigns.date_to != "" and socket.assigns.date_to != nil do
        case Date.from_iso8601(socket.assigns.date_to) do
          {:ok, date} ->
            # Convert date to datetime at end of day (23:59:59)
            datetime = DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")
            Ash.Query.filter(query, contribution_date <= ^datetime)

          _ ->
            query
        end
      else
        query
      end

    # Filter by amount range
    query =
      if socket.assigns.amount_min != "" and socket.assigns.amount_min != nil do
        case Decimal.parse(socket.assigns.amount_min) do
          {amount, _} ->
            Ash.Query.filter(query, revenue >= ^amount)

          :error ->
            query
        end
      else
        query
      end

    query =
      if socket.assigns.amount_max != "" and socket.assigns.amount_max != nil do
        case Decimal.parse(socket.assigns.amount_max) do
          {amount, _} ->
            Ash.Query.filter(query, revenue <= ^amount)

          :error ->
            query
        end
      else
        query
      end

    # Get total count for pagination
    all_contributions = Ash.read!(query, actor: actor)
    total_count = length(all_contributions)
    total_pages = ceil(total_count / socket.assigns.per_page)

    # Apply pagination
    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    paginated_query =
      query
      |> Ash.Query.limit(socket.assigns.per_page)
      |> Ash.Query.offset(offset)

    contributions = Ash.read!(paginated_query, actor: actor)

    socket
    |> assign(:contributions, contributions)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active" phx-click="close_menu">
      <%!-- Floating Action Bar for Bulk Selection --%>
      <%= if MapSet.size(@selected_ids) > 0 do %>
        <div class="fixed bottom-8 left-1/2 transform -translate-x-1/2 z-50 animate-slide-up">
          <div class="floating-action-bar shadow-2xl rounded-full px-6 py-3 flex items-center gap-6 bg-dark-800 border border-dark-600">
            <div class="flex items-center gap-2">
              <.icon name="hero-check-circle" class="h-5 w-5 text-primary-500" />
              <span class="text-sm font-medium text-white">
                {MapSet.size(@selected_ids)} selected
              </span>
            </div>
            <div class="h-6 w-px bg-dark-600"></div>
            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="clear_selection"
                class="floating-cancel-btn inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 rounded-full border border-dark-600"
                aria-label="Clear selection"
              >
                <.icon name="hero-x-mark" class="mr-2 h-4 w-4" /> Cancel
              </button>
              <button
                type="button"
                phx-click="show_delete_confirm"
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-full transition-colors"
              >
                <.icon name="hero-trash" class="mr-2 h-4 w-4" /> Delete Selected
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div class="flex items-center gap-4">
          <h2 class="text-2xl font-bold text-white">Contributions</h2>
        </div>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/contributions/new"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" /> New Contribution
          </.link>
        </div>
      </div>

      <div class="mb-6 space-y-4">
        <div class="flex flex-col sm:flex-row gap-4">
          <form phx-change="search" phx-submit="search" onsubmit="return false;" class="relative flex-1">
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-4 top-1/2 h-4 w-4 text-gray-500 transform -translate-y-1/2 pointer-events-none z-10"
            />
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search by type, name, or full name (e.g., John Smith)..."
              style="padding-left: 2.75rem;"
              class="w-full pr-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </form>
          <form phx-change="filter_type">
            <select
              name="type"
              value={@type_filter}
              class="h-[42px] px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
            >
              <option value="">All Types</option>
              <%= for type <- Chms.Church.ContributionTypes.all_types() do %>
                <option value={type}>{type}</option>
              <% end %>
            </select>
          </form>
          <button
            type="button"
            phx-click="toggle_advanced_filters"
            class="inline-flex items-center h-[42px] px-4 py-2 text-sm font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded-md hover:bg-dark-700 hover:border-dark-600 transition-colors whitespace-nowrap"
          >
            <.icon name="hero-funnel" class="mr-2 h-4 w-4" />
            {if @show_advanced_filters, do: "Hide Filters", else: "More Filters"}
          </button>
        </div>

        <%!-- Advanced Filters Section --%>
        <%= if @show_advanced_filters do %>
          <div class="bg-dark-800 border border-dark-700 rounded-lg p-4 space-y-4 animate-fade-in">
            <div class="flex items-center justify-between mb-2">
              <h3 class="text-sm font-medium text-white flex items-center">
                <.icon name="hero-adjustments-horizontal" class="mr-2 h-4 w-4 text-primary-500" />
                Advanced Filters
              </h3>
              <button
                type="button"
                phx-click="clear_filters"
                class="text-xs text-gray-400 hover:text-primary-500 transition-colors"
              >
                Clear All Filters
              </button>
            </div>

            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <%!-- Date Range Filter --%>
              <div class="space-y-2">
                <label class="block text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Date Range
                </label>
                <form phx-change="filter_date" class="grid grid-cols-2 gap-2">
                  <div>
                    <input
                      type="date"
                      id="filter-date-from"
                      name="date_from"
                      value={@date_from}
                      phx-hook="DatePicker"
                      placeholder="From"
                      class="w-full px-3 py-2 text-sm text-white bg-dark-900 border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>
                  <div>
                    <input
                      type="date"
                      id="filter-date-to"
                      name="date_to"
                      value={@date_to}
                      phx-hook="DatePicker"
                      placeholder="To"
                      class="w-full px-3 py-2 text-sm text-white bg-dark-900 border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>
                </form>
              </div>

              <%!-- Amount Range Filter --%>
              <div class="space-y-2">
                <label class="block text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Amount Range
                </label>
                <form phx-change="filter_amount" class="grid grid-cols-2 gap-2">
                  <div class="relative">
                    <span class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500 text-sm">
                      $
                    </span>
                    <input
                      type="number"
                      name="amount_min"
                      value={@amount_min}
                      step="0.01"
                      min="0"
                      placeholder="Min"
                      class="w-full pl-7 pr-3 py-2 text-sm text-white bg-dark-900 border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>
                  <div class="relative">
                    <span class="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500 text-sm">
                      $
                    </span>
                    <input
                      type="number"
                      name="amount_max"
                      value={@amount_max}
                      step="0.01"
                      min="0"
                      placeholder="Max"
                      class="w-full pl-7 pr-3 py-2 text-sm text-white bg-dark-900 border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>
                </form>
              </div>
            </div>

            <%!-- Active Filters Display --%>
            <div
              :if={
                @date_from != "" or @date_to != "" or @amount_min != "" or @amount_max != "" or
                  @type_filter != ""
              }
              class="flex flex-wrap gap-2 pt-2 border-t border-dark-700"
            >
              <span class="text-xs text-gray-400">Active filters:</span>
              <span
                :if={@type_filter != ""}
                class="inline-flex items-center px-2 py-1 text-xs bg-primary-500/10 text-primary-500 rounded-md border border-primary-500/20"
              >
                Type: {@type_filter}
              </span>
              <span
                :if={@date_from != ""}
                class="inline-flex items-center px-2 py-1 text-xs bg-primary-500/10 text-primary-500 rounded-md border border-primary-500/20"
              >
                From: {@date_from}
              </span>
              <span
                :if={@date_to != ""}
                class="inline-flex items-center px-2 py-1 text-xs bg-primary-500/10 text-primary-500 rounded-md border border-primary-500/20"
              >
                To: {@date_to}
              </span>
              <span
                :if={@amount_min != ""}
                class="inline-flex items-center px-2 py-1 text-xs bg-primary-500/10 text-primary-500 rounded-md border border-primary-500/20"
              >
                Min: ${@amount_min}
              </span>
              <span
                :if={@amount_max != ""}
                class="inline-flex items-center px-2 py-1 text-xs bg-primary-500/10 text-primary-500 rounded-md border border-primary-500/20"
              >
                Max: ${@amount_max}
              </span>
            </div>
          </div>
        <% end %>
      </div>

      <div class="bg-dark-800 rounded-lg shadow-xl overflow-x-auto overflow-y-visible">
        <table class="min-w-full">
          <thead>
            <tr class="border-b border-dark-700">
              <th scope="col" class="px-6 py-4 w-12">
                <input
                  type="checkbox"
                  phx-click="toggle_select_all"
                  checked={
                    MapSet.size(@selected_ids) > 0 &&
                      MapSet.size(@selected_ids) == length(@contributions)
                  }
                  class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                  aria-label="Select all"
                />
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Date
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Congregant
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Type
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Amount
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="bg-dark-800">
            <tr
              :for={{contribution, index} <- Enum.with_index(@contributions)}
              class={[
                "border-b border-dark-700 hover:bg-dark-700/40 transition-all duration-200 group",
                MapSet.member?(@selected_ids, contribution.id) && "bg-primary-900/20"
              ]}
            >
              <td class="px-6 py-5 w-12">
                <input
                  type="checkbox"
                  phx-click="toggle_select"
                  phx-value-id={contribution.id}
                  checked={MapSet.member?(@selected_ids, contribution.id)}
                  class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                  aria-label={"Select contribution from #{contribution.congregant.first_name} #{contribution.congregant.last_name}"}
                />
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap text-sm text-gray-300 cursor-pointer"
                phx-click={JS.navigate(~p"/contributions/#{contribution}")}
              >
                {Calendar.strftime(contribution.contribution_date, "%B %d, %Y")}
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap text-sm text-white cursor-pointer"
                phx-click={JS.navigate(~p"/contributions/#{contribution}")}
              >
                {contribution.congregant.first_name} {contribution.congregant.last_name}
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap cursor-pointer"
                phx-click={JS.navigate(~p"/contributions/#{contribution}")}
              >
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-500/10 text-primary-500 border border-primary-500/20">
                  {contribution.contribution_type}
                </span>
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap text-sm font-medium text-green-400 cursor-pointer"
                phx-click={JS.navigate(~p"/contributions/#{contribution}")}
              >
                ${Decimal.to_string(contribution.revenue, :normal)}
              </td>
              <td class="px-6 py-5 text-right">
                <div class="flex items-center justify-end relative group">
                  <button
                    type="button"
                    phx-click="toggle_menu"
                    phx-value-id={contribution.id}
                    class="p-2 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                    aria-label="Actions menu"
                  >
                    <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
                  </button>

                  <%!-- Dropdown Menu - opens upward for last 3 rows, downward otherwise --%>
                  <div
                    :if={@open_menu_id == contribution.id}
                    class={[
                      "absolute right-0 w-48 rounded-md shadow-lg bg-dark-700 ring-1 ring-dark-600 z-50",
                      if(index >= length(@contributions) - 3,
                        do: "bottom-full mb-2",
                        else: "top-full mt-2"
                      )
                    ]}
                  >
                    <div class="py-1" role="menu" aria-orientation="vertical">
                      <.link
                        navigate={~p"/contributions/#{contribution}"}
                        class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                        role="menuitem"
                      >
                        <.icon name="hero-eye" class="mr-3 h-4 w-4" /> View Details
                      </.link>

                      <.link
                        navigate={~p"/contributions/#{contribution}/edit"}
                        class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                        role="menuitem"
                      >
                        <.icon name="hero-pencil-square" class="mr-3 h-4 w-4" /> Edit Contribution
                      </.link>

                      <button
                        type="button"
                        phx-click="show_delete_single"
                        phx-value-id={contribution.id}
                        class="flex items-center w-full px-4 py-2 text-sm text-red-400 hover:bg-dark-600 hover:text-red-300 transition-colors text-left"
                        role="menuitem"
                      >
                        <.icon name="hero-trash" class="mr-3 h-4 w-4" /> Delete Contribution
                      </button>
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
        <div class="px-6 py-4 flex flex-col sm:flex-row items-center justify-between gap-4 bg-dark-800 border-t border-dark-700">
          <div class="text-sm text-gray-500">
            Showing {(@page - 1) * @per_page + 1} to {min(@page * @per_page, @total_count)} of {@total_count} results
          </div>
          <div class="flex items-center gap-2">
            <%!-- Previous Button --%>
            <button
              type="button"
              phx-click="paginate"
              phx-value-page={@page - 1}
              disabled={@page == 1}
              class={[
                "relative inline-flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors",
                @page == 1 && "text-gray-500 cursor-not-allowed opacity-50",
                @page > 1 && "text-gray-300 hover:text-white hover:bg-dark-700"
              ]}
            >
              <.icon name="hero-chevron-left" class="mr-1 h-4 w-4" /> Previous
            </button>

            <%!-- Page Numbers --%>
            <div class="hidden sm:flex items-center gap-1">
              <%= for page_num <- pagination_range(@page, @total_pages) do %>
                <%= if page_num == :ellipsis do %>
                  <span class="px-3 py-2 text-sm text-gray-500">...</span>
                <% else %>
                  <button
                    type="button"
                    phx-click="paginate"
                    phx-value-page={page_num}
                    class={[
                      "px-3 py-2 text-sm font-medium rounded-md transition-colors",
                      page_num == @page && "bg-primary-500 text-white",
                      page_num != @page && "text-gray-300 hover:text-white hover:bg-dark-700"
                    ]}
                  >
                    {page_num}
                  </button>
                <% end %>
              <% end %>
            </div>

            <%!-- Mobile Page Indicator --%>
            <div class="sm:hidden text-sm text-gray-400">
              Page {@page} of {@total_pages}
            </div>

            <%!-- Next Button --%>
            <button
              type="button"
              phx-click="paginate"
              phx-value-page={@page + 1}
              disabled={@page >= @total_pages}
              class={[
                "relative inline-flex items-center px-4 py-2 text-sm font-medium rounded-md transition-colors",
                @page >= @total_pages && "text-gray-500 cursor-not-allowed opacity-50",
                @page < @total_pages && "text-gray-300 hover:text-white hover:bg-dark-700"
              ]}
            >
              Next <.icon name="hero-chevron-right" class="ml-1 h-4 w-4" />
            </button>
          </div>
        </div>
      </div>

      <%!-- Single Delete Confirmation Modal --%>
      <%= if @delete_single_id do %>
        <div
          class="fixed inset-0 z-[100] overflow-y-auto"
          aria-labelledby="modal-title-single"
          role="dialog"
          aria-modal="true"
        >
          <%!-- Background overlay --%>
          <div class="fixed inset-0 modal-backdrop transition-opacity"></div>

          <%!-- Modal panel --%>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-lg">
              <%!-- Modal content --%>
              <div class="p-6">
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-red-900/20">
                      <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-white mb-2" id="modal-title-single">
                      Delete Contribution
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete this contribution? This action cannot be undone.
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Modal actions --%>
              <div class="px-6 py-4 bg-dark-700/50 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="cancel_delete_single"
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="confirm_delete_single"
                  class="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md transition-colors"
                >
                  Delete Contribution
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Bulk Delete Confirmation Modal --%>
      <%= if @show_delete_confirm do %>
        <div
          class="fixed inset-0 z-[100] overflow-y-auto"
          aria-labelledby="modal-title"
          role="dialog"
          aria-modal="true"
        >
          <%!-- Background overlay --%>
          <div class="fixed inset-0 modal-backdrop transition-opacity"></div>

          <%!-- Modal panel --%>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-lg">
              <%!-- Modal content --%>
              <div class="p-6">
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-red-900/20">
                      <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-white mb-2" id="modal-title">
                      Delete Contributions
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete {MapSet.size(@selected_ids)} contribution(s)? This action cannot be undone.
                    </p>
                  </div>
                </div>
              </div>

              <%!-- Modal actions --%>
              <div class="px-6 py-4 bg-dark-700/50 flex justify-end gap-3">
                <button
                  type="button"
                  phx-click="cancel_delete"
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="confirm_delete_selected"
                  class="px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md transition-colors"
                >
                  Delete Contributions
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Generate pagination range with ellipsis
  defp pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        Enum.to_list(1..5) ++ [:ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++ [:ellipsis, total_pages]
    end
  end
end
