defmodule ChurchappWeb.CongregantsLive.IndexLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Congregants")
      |> assign(:sort_by, :first_name)
      |> assign(:sort_dir, :asc)
      |> assign(:search_query, "")
      |> assign(:status_filter, "")
      |> assign(:open_menu_id, nil)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:show_delete_confirm, false)
      |> assign(:delete_single_id, nil)
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> fetch_congregants()

    {:ok, socket}
  end

  def handle_event("sort", %{"col" => col}, socket) do
    column = String.to_existing_atom(col)

    new_dir =
      if socket.assigns.sort_by == column and socket.assigns.sort_dir == :asc do
        :desc
      else
        :asc
      end

    socket
    |> assign(:sort_by, column)
    |> assign(:sort_dir, new_dir)
    |> fetch_congregants()
    |> then(&{:noreply, &1})
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket
    |> assign(:search_query, query)
    |> assign(:page, 1)
    |> fetch_congregants()
    |> then(&{:noreply, &1})
  end

  def handle_event("filter_status", %{"status" => status}, socket) do
    socket
    |> assign(:status_filter, status)
    |> assign(:page, 1)
    |> fetch_congregants()
    |> then(&{:noreply, &1})
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    socket
    |> assign(:page, String.to_integer(page))
    |> assign(:selected_ids, MapSet.new())
    |> fetch_congregants()
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
    all_ids = Enum.map(socket.assigns.congregants, & &1.id) |> MapSet.new()

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
    count = MapSet.size(socket.assigns.selected_ids)

    Enum.each(socket.assigns.selected_ids, fn id ->
      case Chms.Church.get_congregant_by_id(id) do
        {:ok, congregant} -> Chms.Church.destroy_congregant(congregant)
        _ -> :ok
      end
    end)

    socket
    |> put_flash(:info, "Successfully deleted #{count} member(s)")
    |> assign(:selected_ids, MapSet.new())
    |> assign(:show_delete_confirm, false)
    |> fetch_congregants()
    |> then(&{:noreply, &1})
  end

  def handle_event("show_delete_single", %{"id" => id}, socket) do
    {:noreply, assign(socket, delete_single_id: id, open_menu_id: nil)}
  end

  def handle_event("cancel_delete_single", _params, socket) do
    {:noreply, assign(socket, :delete_single_id, nil)}
  end

  def handle_event("confirm_delete_single", _params, socket) do
    case Chms.Church.get_congregant_by_id(socket.assigns.delete_single_id) do
      {:ok, congregant} ->
        {:ok, _} = Chms.Church.destroy_congregant(congregant)

        socket
        |> put_flash(:info, "Congregant deleted successfully")
        |> assign(:delete_single_id, nil)
        |> fetch_congregants()
        |> then(&{:noreply, &1})

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete congregant")
         |> assign(:delete_single_id, nil)}
    end
  end

  def handle_event("toggle_menu", %{"id" => id}, socket) do
    new_menu_id = if socket.assigns.open_menu_id == id, do: nil, else: id
    {:noreply, assign(socket, :open_menu_id, new_menu_id)}
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, :open_menu_id, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:ok, congregant} = Chms.Church.get_congregant_by_id(id)
    {:ok, _} = Chms.Church.destroy_congregant(congregant)

    socket
    |> put_flash(:info, "Congregant deleted successfully")
    |> assign(:open_menu_id, nil)
    |> fetch_congregants()
    |> then(&{:noreply, &1})
  end

  defp fetch_congregants(socket) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.sort([{socket.assigns.sort_by, socket.assigns.sort_dir}])

    query =
      if socket.assigns.search_query != "" do
        # Check if query is a number for ID search
        case Integer.parse(socket.assigns.search_query) do
          {id, ""} ->
            search_term = String.downcase(socket.assigns.search_query)

            Ash.Query.filter(
              query,
              member_id == ^id or contains(string_downcase(first_name), ^search_term) or
                contains(string_downcase(last_name), ^search_term)
            )

          _ ->
            search_term = String.downcase(socket.assigns.search_query)

            Ash.Query.filter(
              query,
              contains(string_downcase(first_name), ^search_term) or
                contains(string_downcase(last_name), ^search_term)
            )
        end
      else
        query
      end

    query =
      if socket.assigns.status_filter != "" do
        status = String.to_existing_atom(socket.assigns.status_filter)
        Ash.Query.filter(query, status == ^status)
      else
        query
      end

    # Get total count for pagination
    {:ok, all_congregants} = Chms.Church.list_congregants(query: query)
    total_count = length(all_congregants)
    total_pages = ceil(total_count / socket.assigns.per_page)

    # Apply pagination
    offset = (socket.assigns.page - 1) * socket.assigns.per_page

    paginated_query =
      query
      |> Ash.Query.limit(socket.assigns.per_page)
      |> Ash.Query.offset(offset)

    {:ok, congregants} = Chms.Church.list_congregants(query: paginated_query)

    socket
    |> assign(:congregants, congregants)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active" phx-click="close_menu">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div class="flex items-center gap-4">
          <h2 class="text-2xl font-bold text-white">All Congregants</h2>
        </div>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/congregants/new"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add New Congregant
          </.link>
        </div>
      </div>

      <%!-- Floating Action Bar for Selected Items --%>
      <%= if MapSet.size(@selected_ids) > 0 do %>
        <div class="fixed bottom-6 left-[40%] z-50 animate-slide-up">
          <div class="flex items-center gap-4 px-6 py-4 bg-dark-800 border-2 border-primary-500 rounded-full shadow-2xl shadow-primary-500/30">
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

      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <div class="relative flex-1">
          <.icon
            name="hero-magnifying-glass"
            class="absolute left-3 top-1/2 h-4 w-4 text-gray-500 transform -translate-y-1/2"
          />
          <form phx-change="search" phx-submit="search" onsubmit="return false;">
            <input
              type="text"
              name="query"
              value={@search_query}
              placeholder="Search members by name..."
              class="w-full pl-10 pr-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
            />
          </form>
        </div>
        <form phx-change="filter_status">
          <select
            name="status"
            value={@status_filter}
            class="h-[42px] px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
          >
            <option value="">All Statuses</option>
            <option value="member">Active Member</option>
            <option value="visitor">Visitor</option>
            <option value="honorific">Honorific</option>
            <option value="deceased">Deceased</option>
          </select>
        </form>
      </div>

      <div class="bg-dark-800 rounded-lg shadow-xl overflow-hidden">
        <table class="min-w-full">
          <thead>
            <tr class="border-b border-dark-700">
              <th scope="col" class="px-6 py-4 w-12">
                <input
                  type="checkbox"
                  phx-click="toggle_select_all"
                  checked={
                    MapSet.size(@selected_ids) > 0 &&
                      MapSet.size(@selected_ids) == length(@congregants)
                  }
                  class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                  aria-label="Select all"
                />
              </th>
              <.sort_header label="Member" key={:first_name} sort_by={@sort_by} sort_dir={@sort_dir} />
              <.sort_header
                label="Contact Info"
                key={:address}
                sort_by={@sort_by}
                sort_dir={@sort_dir}
              />
              <.sort_header label="Status" key={:status} sort_by={@sort_by} sort_dir={@sort_dir} />
              <.sort_header label="Ministry" key={:is_leader} sort_by={@sort_by} sort_dir={@sort_dir} />
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
              :for={congregant <- @congregants}
              class={[
                "border-b border-dark-700 hover:bg-dark-700/40 transition-all duration-200 group",
                MapSet.member?(@selected_ids, congregant.id) && "bg-primary-900/20"
              ]}
            >
              <td class="px-6 py-5 w-12">
                <input
                  type="checkbox"
                  phx-click="toggle_select"
                  phx-value-id={congregant.id}
                  checked={MapSet.member?(@selected_ids, congregant.id)}
                  class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                  aria-label={"Select #{congregant.first_name} #{congregant.last_name}"}
                />
              </td>
              <td
                class="px-6 py-5 cursor-pointer"
                phx-click={JS.navigate(~p"/congregants/#{congregant}")}
              >
                <div class="flex items-center">
                  <img
                    src={
                      if congregant.image && congregant.image != "",
                        do: congregant.image,
                        else:
                          "https://ui-avatars.com/api/?name=#{URI.encode(congregant.first_name <> "+" <> congregant.last_name)}&background=404040&color=D1D5DB&bold=true"
                    }
                    alt=""
                    class="h-12 w-12 rounded-full object-cover"
                  />
                  <div class="ml-4">
                    <div class="text-base font-medium text-white">
                      {congregant.first_name} {congregant.last_name}
                    </div>
                    <div class="text-sm text-gray-500">
                      Joined {if congregant.member_since,
                        do: Calendar.strftime(congregant.member_since, "%b %Y"),
                        else: "N/A"}
                    </div>
                  </div>
                </div>
              </td>
              <td
                class="px-6 py-5 cursor-pointer"
                phx-click={JS.navigate(~p"/congregants/#{congregant}")}
              >
                <div class="text-sm text-gray-300">
                  {if congregant.address, do: congregant.address, else: "—"}
                </div>
                <div class="text-sm text-gray-500">
                  {format_phone(congregant.mobile_tel)}
                </div>
              </td>
              <td
                class="px-6 py-5 cursor-pointer"
                phx-click={JS.navigate(~p"/congregants/#{congregant}")}
              >
                <span class={[
                  "px-3 py-1 inline-flex text-sm font-medium rounded-full",
                  congregant.status == :member && "bg-green-900/60 text-green-400",
                  congregant.status == :visitor && "bg-yellow-900/60 text-yellow-500",
                  congregant.status == :deceased && "bg-gray-800 text-gray-400",
                  congregant.status == :honorific && "bg-blue-900/60 text-blue-400"
                ]}>
                  {case congregant.status do
                    :member -> "Member"
                    :visitor -> "Visitor"
                    :deceased -> "Deceased"
                    :honorific -> "Honorific"
                    _ -> congregant.status |> to_string() |> String.capitalize()
                  end}
                </span>
              </td>
              <td
                class="px-6 py-5 text-sm text-gray-300 cursor-pointer"
                phx-click={JS.navigate(~p"/congregants/#{congregant}")}
              >
                {if congregant.is_leader, do: "Worship Team, Kids Ministry", else: "—"}
              </td>
              <td class="px-6 py-5 text-right relative">
                <div class="flex items-center justify-end">
                  <button
                    type="button"
                    phx-click="toggle_menu"
                    phx-value-id={congregant.id}
                    class="p-2 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                    aria-label="Actions menu"
                  >
                    <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
                  </button>

                  <%!-- Dropdown Menu --%>
                  <div
                    :if={@open_menu_id == congregant.id}
                    class="absolute right-0 mt-2 w-48 rounded-md shadow-lg bg-dark-700 ring-1 ring-dark-600 z-10"
                    style="top: 100%;"
                  >
                    <div class="py-1" role="menu" aria-orientation="vertical">
                      <.link
                        navigate={~p"/congregants/#{congregant}"}
                        class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                        role="menuitem"
                      >
                        <.icon name="hero-eye" class="mr-3 h-4 w-4" /> View Details
                      </.link>

                      <.link
                        navigate={~p"/congregants/#{congregant}/edit"}
                        class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                        role="menuitem"
                      >
                        <.icon name="hero-pencil-square" class="mr-3 h-4 w-4" /> Edit Congregant
                      </.link>

                      <button
                        type="button"
                        phx-click="show_delete_single"
                        phx-value-id={congregant.id}
                        class="flex items-center w-full px-4 py-2 text-sm text-red-400 hover:bg-dark-600 hover:text-red-300 transition-colors text-left"
                        role="menuitem"
                      >
                        <.icon name="hero-trash" class="mr-3 h-4 w-4" /> Delete Congregant
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

      <%!-- Custom Delete Confirmation Modal --%>
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
                      Delete Members
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete {MapSet.size(@selected_ids)} member(s)? This action cannot be undone.
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
                  Delete Members
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

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
                      Delete Member
                    </h3>
                    <p class="text-sm text-gray-300">
                      Are you sure you want to delete this member? This action cannot be undone.
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
                  Delete Member
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp sort_header(assigns) do
    ~H"""
    <th
      scope="col"
      class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-gray-300 group select-none"
      phx-click="sort"
      phx-value-col={@key}
    >
      <div class="flex items-center gap-2">
        {@label}
        <.icon
          name={sort_indicator_icon(@key, @sort_by, @sort_dir)}
          class={"h-4 w-4 transition-colors " <> sort_indicator_class(@key, @sort_by)}
        />
      </div>
    </th>
    """
  end

  defp sort_indicator_icon(column, sort_by, sort_dir) do
    if column == sort_by do
      if sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"
    else
      "hero-arrows-up-down"
    end
  end

  defp sort_indicator_class(column, sort_by) do
    if column == sort_by do
      "text-primary-500"
    else
      "text-gray-700 group-hover:text-gray-500"
    end
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

  # Format phone number for display: (123) 456 - 7890
  defp format_phone(nil), do: "—"
  defp format_phone(""), do: "—"

  defp format_phone(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    case String.length(digits) do
      10 ->
        "(#{String.slice(digits, 0, 3)}) #{String.slice(digits, 3, 3)} - #{String.slice(digits, 6, 4)}"

      _ ->
        # Return as-is if not 10 digits
        phone
    end
  end
end
