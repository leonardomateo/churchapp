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
    |> fetch_congregants()
    |> then(&{:noreply, &1})
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:ok, congregant} = Chms.Church.get_congregant_by_id(id)
    {:ok, _} = Chms.Church.destroy_congregant(congregant)

    socket
    |> put_flash(:info, "Congregant deleted successfully")
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
            Ash.Query.filter(query, member_id == ^id or contains(string_downcase(first_name), ^search_term) or contains(string_downcase(last_name), ^search_term))
          _ ->
            search_term = String.downcase(socket.assigns.search_query)
            Ash.Query.filter(query, contains(string_downcase(first_name), ^search_term) or contains(string_downcase(last_name), ^search_term))
        end
      else
        query
      end

    {:ok, congregants} = Chms.Church.list_congregants(query: query)
    assign(socket, :congregants, congregants)
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <h2 class="text-2xl font-bold text-white">All Members</h2>
        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/congregants/new"}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
          >
            <.icon name="hero-plus" class="mr-2 h-4 w-4" />
            Add New Member
          </.link>
        </div>
      </div>

      <div class="mb-6 flex flex-col sm:flex-row gap-4">
        <div class="relative flex-1">
          <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 h-4 w-4 text-gray-500 transform -translate-y-1/2" />
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
        <select class="px-3 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-primary-500 focus:border-primary-500">
          <option value="">All Statuses</option>
          <option value="active">Active Member</option>
          <option value="pending">Visitor/Pending</option>
          <option value="inactive">Inactive</option>
        </select>
      </div>

      <div class="bg-dark-800 rounded-lg shadow-xl overflow-hidden">
        <table class="min-w-full">
          <thead>
            <tr class="border-b border-dark-700">
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Member
              </th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Contact Info
              </th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Status
              </th>
              <th scope="col" class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Ministry
              </th>
            </tr>
          </thead>
          <tbody class="bg-dark-800">
            <tr
              :for={congregant <- @congregants}
              phx-click={JS.navigate(~p"/congregants/#{congregant}")}
              class="border-b border-dark-700 hover:bg-dark-700/40 transition-all duration-200 cursor-pointer group"
            >
              <td class="px-6 py-5">
                <div class="flex items-center">
                  <img
                    src={"https://ui-avatars.com/api/?name=#{URI.encode(congregant.first_name <> "+" <> congregant.last_name)}&background=404040&color=D1D5DB&bold=true"}
                    alt=""
                    class="h-12 w-12 rounded-full object-cover"
                  />
                  <div class="ml-4">
                    <div class="text-base font-medium text-white">
                      {congregant.first_name} {congregant.last_name}
                    </div>
                    <div class="text-sm text-gray-500">
                      Joined {if congregant.member_since, do: Calendar.strftime(congregant.member_since, "%b %Y"), else: "N/A"}
                    </div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-5">
                <div class="text-sm text-gray-300">
                  {if congregant.address, do: congregant.address, else: "—"}
                </div>
                <div class="text-sm text-gray-500">
                  {format_phone(congregant.mobile_tel)}
                </div>
              </td>
              <td class="px-6 py-5">
                <span class={[
                  "px-3 py-1 inline-flex text-sm font-medium rounded-full",
                  congregant.status == :member && "bg-green-900/60 text-green-400",
                  congregant.status == :visitor && "bg-yellow-900/60 text-yellow-500",
                  congregant.status == :deceased && "bg-gray-800 text-gray-400",
                  congregant.status == :honorific && "bg-blue-900/60 text-blue-400"
                ]}>
                  {case congregant.status do
                    :member -> "Active Member"
                    :visitor -> "Visitor"
                    :deceased -> "Deceased"
                    :honorific -> "Honorific"
                    _ -> congregant.status |> to_string() |> String.capitalize()
                  end}
                </span>
              </td>
              <td class="px-6 py-5 text-sm text-gray-300">
                {if congregant.is_leader, do: "Worship Team, Kids Ministry", else: "—"}
              </td>
            </tr>
          </tbody>
        </table>
        <div class="px-6 py-4 flex items-center justify-between bg-dark-800 border-t border-dark-700">
          <div class="text-sm text-gray-500">
            Showing 1 to {length(@congregants)} of {length(@congregants)} results
          </div>
          <div class="flex space-x-2">
            <button
              disabled
              class="relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-500 hover:text-gray-400 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Previous
            </button>
            <button
              disabled
              class="relative inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 hover:text-white disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </div>
    """
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
        phone  # Return as-is if not 10 digits
    end
  end
end
