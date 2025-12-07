defmodule ChurchappWeb.MinistryFundsLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Ministry Funds")
      |> assign(:search_query, "")
      |> assign(:ministry_filter, "")
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
      |> fetch_ministry_funds()

    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket
    |> assign(:search_query, query)
    |> assign(:page, 1)
    |> fetch_ministry_funds()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_ministry", %{"ministry" => ministry}, socket) do
    socket
    |> assign(:ministry_filter, ministry)
    |> assign(:page, 1)
    |> fetch_ministry_funds()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_type", %{"type" => type}, socket) do
    socket
    |> assign(:type_filter, type)
    |> assign(:page, 1)
    |> fetch_ministry_funds()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_date", %{"date_from" => date_from, "date_to" => date_to}, socket) do
    socket
    |> assign(:date_from, date_from)
    |> assign(:date_to, date_to)
    |> assign(:page, 1)
    |> fetch_ministry_funds()
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
    |> fetch_ministry_funds()
    |> then(&{:noreply, &1})
  end

  def handle_event("toggle_advanced_filters", _params, socket) do
    {:noreply, assign(socket, :show_advanced_filters, !socket.assigns.show_advanced_filters)}
  end

  def handle_event("clear_filters", _params, socket) do
    socket
    |> assign(:search_query, "")
    |> assign(:ministry_filter, "")
    |> assign(:type_filter, "")
    |> assign(:date_from, "")
    |> assign(:date_to, "")
    |> assign(:amount_min, "")
    |> assign(:amount_max, "")
    |> assign(:page, 1)
    |> fetch_ministry_funds()
    |> then(&{:noreply, &1})
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    socket
    |> assign(:page, String.to_integer(page))
    |> assign(:selected_ids, MapSet.new())
    |> fetch_ministry_funds()
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
    all_ids = Enum.map(socket.assigns.ministry_funds, & &1.id) |> MapSet.new()

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
      case Ash.get(Chms.Church.MinistryFunds, id, actor: actor) do
        {:ok, ministry_fund} -> Ash.destroy(ministry_fund, actor: actor)
        _ -> :ok
      end
    end)

    socket
    |> put_flash(:info, "Successfully deleted #{count} transaction(s)")
    |> assign(:selected_ids, MapSet.new())
    |> assign(:show_delete_confirm, false)
    |> fetch_ministry_funds()
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

    ministry_fund =
      Ash.get!(Chms.Church.MinistryFunds, socket.assigns.delete_single_id, actor: actor)

    case Ash.destroy(ministry_fund, actor: actor) do
      :ok ->
        socket
        |> put_flash(:info, "Transaction deleted successfully")
        |> assign(:delete_single_id, nil)
        |> fetch_ministry_funds()
        |> then(&{:noreply, &1})

      {:error, _error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete transaction")
         |> assign(:delete_single_id, nil)}
    end
  end

  defp fetch_ministry_funds(socket) do
    actor = socket.assigns[:current_user]

    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.sort(transaction_date: :desc)

    query =
      if socket.assigns.search_query != "" do
        search_term = String.downcase(socket.assigns.search_query)

        Ash.Query.filter(
          query,
          contains(string_downcase(ministry_name), ^search_term) or
            contains(string_downcase(notes), ^search_term)
        )
      else
        query
      end

    query =
      if socket.assigns.ministry_filter != "" do
        Ash.Query.filter(query, ministry_name == ^socket.assigns.ministry_filter)
      else
        query
      end

    query =
      if socket.assigns.type_filter != "" do
        type_atom = String.to_existing_atom(socket.assigns.type_filter)
        Ash.Query.filter(query, transaction_type == ^type_atom)
      else
        query
      end

    # Filter by date range
    query =
      if socket.assigns.date_from != "" and socket.assigns.date_from != nil do
        case Date.from_iso8601(socket.assigns.date_from) do
          {:ok, date} ->
            datetime = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
            Ash.Query.filter(query, transaction_date >= ^datetime)

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
            datetime = DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")
            Ash.Query.filter(query, transaction_date <= ^datetime)

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
            Ash.Query.filter(query, amount >= ^amount)

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
            Ash.Query.filter(query, amount <= ^amount)

          :error ->
            query
        end
      else
        query
      end

    # Get total count for pagination
    all_ministry_funds = Ash.read!(query, actor: actor)
    total_count = length(all_ministry_funds)
    total_pages = ceil(total_count / socket.assigns.per_page)

    # Calculate ministry balances
    ministry_balances = calculate_ministry_balances(all_ministry_funds)

    # Apply pagination
    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    paginated_query =
      query
      |> Ash.Query.limit(socket.assigns.per_page)
      |> Ash.Query.offset(offset)

    ministry_funds = Ash.read!(paginated_query, actor: actor)

    # Get unique ministries for filter dropdown
    unique_ministries =
      all_ministry_funds
      |> Enum.map(& &1.ministry_name)
      |> Enum.uniq()
      |> Enum.sort()

    socket
    |> assign(:ministry_funds, ministry_funds)
    |> assign(:ministry_balances, ministry_balances)
    |> assign(:unique_ministries, unique_ministries)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp calculate_ministry_balances(transactions) do
    transactions
    |> Enum.group_by(& &1.ministry_name)
    |> Enum.map(fn {ministry, txns} ->
      revenues =
        txns
        |> Enum.filter(&(&1.transaction_type == :revenue))
        |> Enum.map(& &1.amount)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      expenses =
        txns
        |> Enum.filter(&(&1.transaction_type == :expense))
        |> Enum.map(& &1.amount)
        |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

      balance = Decimal.sub(revenues, expenses)

      {ministry, balance}
    end)
    |> Map.new()
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
          <h2 class="text-2xl font-bold text-white">Ministry Funds</h2>
        </div>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/ministry-funds/new"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" /> New Transaction
          </.link>
        </div>
      </div>

      <div class="mb-6 space-y-4">
        <div class="flex flex-col sm:flex-row gap-4">
          <form
            phx-change="search"
            phx-submit="search"
            onsubmit="return false;"
            class="relative flex-1"
          >
            <.icon
              name="hero-magnifying-glass"
              class="absolute left-4 top-1/2 h-4 w-4 text-gray-500 transform -translate-y-1/2 pointer-events-none z-10"
            />
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search by ministry name or notes..."
              style="padding-left: 2.75rem;"
              class="w-full pr-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </form>
          <form phx-change="filter_ministry">
            <select
              name="ministry"
              value={@ministry_filter}
              class="h-[42px] px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
            >
              <option value="">All Ministries</option>
              <%= for ministry <- @unique_ministries do %>
                <option value={ministry}>{ministry}</option>
              <% end %>
            </select>
          </form>
          <form phx-change="filter_type">
            <select
              name="type"
              value={@type_filter}
              class="h-[42px] px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
            >
              <option value="">All Types</option>
              <option value="revenue">Revenue</option>
              <option value="expense">Expense</option>
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
                  @ministry_filter != "" or @type_filter != ""
              }
              class="flex flex-wrap gap-2 pt-2 border-t border-dark-700"
            >
              <span class="text-xs text-gray-400">Active filters:</span>
              <span
                :if={@ministry_filter != ""}
                class="inline-flex items-center px-2 py-1 text-xs bg-primary-500/10 text-primary-500 rounded-md border border-primary-500/20"
              >
                Ministry: {@ministry_filter}
              </span>
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
                      MapSet.size(@selected_ids) == length(@ministry_funds)
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
                Ministry
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
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Balance
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
              :for={{fund, index} <- Enum.with_index(@ministry_funds)}
              class={[
                "border-b border-dark-700 hover:bg-dark-700/40 transition-all duration-200 group",
                MapSet.member?(@selected_ids, fund.id) && "bg-primary-900/20"
              ]}
            >
              <td class="px-6 py-5 w-12">
                <input
                  type="checkbox"
                  phx-click="toggle_select"
                  phx-value-id={fund.id}
                  checked={MapSet.member?(@selected_ids, fund.id)}
                  class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                  aria-label={"Select transaction for #{fund.ministry_name}"}
                />
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap text-sm text-gray-300 cursor-pointer"
                phx-click={JS.navigate(~p"/ministry-funds/#{fund}")}
              >
                {Calendar.strftime(fund.transaction_date, "%B %d, %Y")}
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap text-sm text-white cursor-pointer"
                phx-click={JS.navigate(~p"/ministry-funds/#{fund}")}
              >
                {fund.ministry_name}
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap cursor-pointer"
                phx-click={JS.navigate(~p"/ministry-funds/#{fund}")}
              >
                <span class={[
                  "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border",
                  fund.transaction_type == :revenue &&
                    "bg-green-500/10 text-green-400 border-green-500/20",
                  fund.transaction_type == :expense &&
                    "bg-red-500/10 text-red-400 border-red-500/20"
                ]}>
                  <%= if fund.transaction_type == :revenue do %>
                    <.icon name="hero-arrow-trending-up" class="mr-1 h-3 w-3" /> Revenue
                  <% else %>
                    <.icon name="hero-arrow-trending-down" class="mr-1 h-3 w-3" /> Expense
                  <% end %>
                </span>
              </td>
              <td
                class={[
                  "px-6 py-5 whitespace-nowrap text-sm font-medium cursor-pointer",
                  fund.transaction_type == :revenue && "text-green-400",
                  fund.transaction_type == :expense && "text-red-400"
                ]}
                phx-click={JS.navigate(~p"/ministry-funds/#{fund}")}
              >
                ${Decimal.to_string(fund.amount, :normal)}
              </td>
              <td
                class="px-6 py-5 whitespace-nowrap text-sm font-medium cursor-pointer"
                phx-click={JS.navigate(~p"/ministry-funds/#{fund}")}
              >
                <% balance = Map.get(@ministry_balances, fund.ministry_name, Decimal.new(0)) %>
                <span class={[
                  "font-semibold",
                  Decimal.positive?(balance) && "text-green-400",
                  Decimal.negative?(balance) && "text-red-400",
                  Decimal.equal?(balance, Decimal.new(0)) && "text-gray-400"
                ]}>
                  ${Decimal.to_string(balance, :normal)}
                </span>
              </td>
              <td class="px-6 py-5 text-right">
                <div class="flex items-center justify-end relative group">
                  <button
                    type="button"
                    phx-click="toggle_menu"
                    phx-value-id={fund.id}
                    class="p-2 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                    aria-label="Actions menu"
                  >
                    <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
                  </button>

                  <%!-- Dropdown Menu --%>
                  <div
                    :if={@open_menu_id == fund.id}
                    class={[
                      "absolute right-0 w-48 rounded-md shadow-lg bg-dark-700 ring-1 ring-dark-600 z-50",
                      if(index >= length(@ministry_funds) - 3,
                        do: "bottom-full mb-2",
                        else: "top-full mt-2"
                      )
                    ]}
                  >
                    <div class="py-1" role="menu" aria-orientation="vertical">
                      <.link
                        navigate={~p"/ministry-funds/#{fund}"}
                        class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                        role="menuitem"
                      >
                        <.icon name="hero-eye" class="mr-3 h-4 w-4" /> View Details
                      </.link>

                      <.link
                        navigate={~p"/ministry-funds/#{fund}/edit"}
                        class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                        role="menuitem"
                      >
                        <.icon name="hero-pencil-square" class="mr-3 h-4 w-4" /> Edit Transaction
                      </.link>

                      <button
                        type="button"
                        phx-click="show_delete_single"
                        phx-value-id={fund.id}
                        class="flex items-center w-full px-4 py-2 text-sm text-red-400 hover:bg-dark-600 hover:text-red-300 transition-colors text-left"
                        role="menuitem"
                      >
                        <.icon name="hero-trash" class="mr-3 h-4 w-4" /> Delete Transaction
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
          <div class="fixed inset-0 modal-backdrop transition-opacity"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-lg">
              <div class="p-6">
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-red-900/20">
                      <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-white mb-2" id="modal-title-single">
                      Delete Transaction
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete this transaction? This action cannot be undone.
                    </p>
                  </div>
                </div>
              </div>
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
                  Delete Transaction
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
          <div class="fixed inset-0 modal-backdrop transition-opacity"></div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-lg">
              <div class="p-6">
                <div class="flex items-start gap-4">
                  <div class="flex-shrink-0">
                    <div class="flex h-12 w-12 items-center justify-center rounded-full bg-red-900/20">
                      <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                    </div>
                  </div>
                  <div class="flex-1">
                    <h3 class="text-lg font-semibold text-white mb-2" id="modal-title">
                      Delete Transactions
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete {MapSet.size(@selected_ids)} transaction(s)? This action cannot be undone.
                    </p>
                  </div>
                </div>
              </div>
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
                  Delete Transactions
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
  defp pagination_range(_current_page, total_pages) when total_pages <= 0 do
    []
  end

  defp pagination_range(current_page, total_pages) do
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages//1)

      current_page <= 4 ->
        Enum.to_list(1..5//1) ++ [:ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages//1)

      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)//1) ++ [:ellipsis, total_pages]
    end
  end
end
