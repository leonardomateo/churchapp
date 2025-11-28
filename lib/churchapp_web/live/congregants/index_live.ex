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
    <div class="space-y-6">
      <div class="flex justify-between items-center">
        <div>
          <h1 class="text-3xl font-bold">Congregants</h1>
          <p class="text-base-content/60 mt-1">Manage your church members and visitors</p>
        </div>
        <div class="flex items-center gap-3">
          <div class="form-control">
            <div class="input-group">
              <form phx-change="search" phx-submit="search">
                <input type="text" name="query" value={@search_query} placeholder="Search..." class="input input-bordered" />
              </form>
            </div>
          </div>
          <Layouts.theme_toggle />
          <.link navigate={~p"/congregants/new"} class="btn btn-primary gap-2">
            <.icon name="hero-plus" class="w-5 h-5" />
            New Member
          </.link>
        </div>
      </div>



      <div class="card bg-base-100 shadow-xl">
        <div class="card-body p-0">
          <div class="overflow-x-auto">
            <table class="table table-zebra table-pin-rows">
              <thead>
                <tr>
                  <th class="cursor-pointer hover:bg-base-200 transition-colors" phx-click="sort" phx-value-col="first_name">
                    <div class="flex items-center gap-2">
                      Name
                      <.icon name={if @sort_by == :first_name, do: (if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"), else: "hero-chevron-up-down"} class={"w-4 h-4 #{if @sort_by == :first_name, do: "opacity-100", else: "opacity-30"}"} />
                    </div>
                  </th>
                  <th class="cursor-pointer hover:bg-base-200 transition-colors" phx-click="sort" phx-value-col="city">
                    <div class="flex items-center gap-2">
                      Location
                      <.icon name={if @sort_by == :city, do: (if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"), else: "hero-chevron-up-down"} class={"w-4 h-4 #{if @sort_by == :city, do: "opacity-100", else: "opacity-30"}"} />
                    </div>
                  </th>
                  <th class="cursor-pointer hover:bg-base-200 transition-colors" phx-click="sort" phx-value-col="status">
                    <div class="flex items-center gap-2">
                      Status
                      <.icon name={if @sort_by == :status, do: (if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"), else: "hero-chevron-up-down"} class={"w-4 h-4 #{if @sort_by == :status, do: "opacity-100", else: "opacity-30"}"} />
                    </div>
                  </th>
                  <th class="cursor-pointer hover:bg-base-200 transition-colors" phx-click="sort" phx-value-col="is_leader">
                    <div class="flex items-center gap-2">
                      Role
                      <.icon name={if @sort_by == :is_leader, do: (if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"), else: "hero-chevron-up-down"} class={"w-4 h-4 #{if @sort_by == :is_leader, do: "opacity-100", else: "opacity-30"}"} />
                    </div>
                  </th>
                  <th class="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={congregant <- @congregants}
                  class="hover hover:bg-base-200/50 transition-colors cursor-pointer group"
                  phx-click={JS.navigate(~p"/congregants/#{congregant}")}
                >
                  <td>
                    <div class="flex items-center gap-3">
                      <div class="avatar placeholder">
                        <div class="bg-neutral text-neutral-content rounded-full w-10">
                          <span class="text-sm">
                            {String.first(congregant.first_name)}{String.first(congregant.last_name)}
                          </span>
                        </div>
                      </div>
                      <div>
                        <div class="font-bold">{congregant.first_name} {congregant.last_name}</div>
                        <div class="text-sm opacity-60">
                          {if congregant.city, do: congregant.city, else: "No location"}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div class="text-sm">
                      <%= if congregant.mobile_tel do %>
                        <div class="flex items-center gap-1">
                          <.icon name="hero-device-phone-mobile" class="w-4 h-4 opacity-60" />
                          {congregant.mobile_tel}
                        </div>
                      <% else %>
                        <span class="opacity-40">No phone</span>
                      <% end %>
                    </div>
                  </td>
                  <td>
                    <div class={[
                      "badge badge-lg gap-1",
                      congregant.status == :member && "badge-success",
                      congregant.status == :visitor && "badge-info",
                      congregant.status == :deceased && "badge-ghost",
                      congregant.status == :honorific && "badge-warning"
                    ]}>
                      <.icon
                        name={
                          case congregant.status do
                            :member -> "hero-check-badge"
                            :visitor -> "hero-user"
                            :deceased -> "hero-heart"
                            :honorific -> "hero-star"
                          end
                        }
                        class="w-3 h-3"
                      />
                      {congregant.status}
                    </div>
                  </td>
                  <td>
                    <%= if congregant.is_leader do %>
                      <div class="badge badge-accent gap-1">
                        <.icon name="hero-shield-check" class="w-3 h-3" />
                        Leader
                      </div>
                    <% else %>
                      <span class="opacity-40">—</span>
                    <% end %>
                  </td>
                  <td>
                    <div class="flex justify-end">
                      <div class="dropdown dropdown-end">
                        <div tabindex="0" role="button" class="btn btn-ghost btn-xs btn-circle">
                          <.icon name="hero-ellipsis-vertical" class="w-5 h-5" />
                        </div>
                        <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow-xl border border-base-300">
                          <li>
                            <.link navigate={~p"/congregants/#{congregant}"} class="gap-2">
                              <.icon name="hero-eye" class="w-4 h-4" />
                              View Details
                            </.link>
                          </li>
                          <li>
                            <.link navigate={~p"/congregants/#{congregant}/edit"} class="gap-2">
                              <.icon name="hero-pencil-square" class="w-4 h-4" />
                              Edit Member
                            </.link>
                          </li>
                          <li>
                            <a
                              phx-click="delete"
                              phx-value-id={congregant.id}
                              data-confirm="Are you sure you want to delete this congregant? This action cannot be undone."
                              class="gap-2 text-error"
                            >
                              <.icon name="hero-trash" class="w-4 h-4" />
                              Delete
                            </a>
                          </li>
                        </ul>
                      </div>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

end
