defmodule PachmsWeb.DashboardLive do
  use PachmsWeb, :live_view

  # In Phoenix 1.7+, basic Tailwind components like .icon, .table, etc. 
  # are usually available in core_components.ex. 
  # We assume standard DaisyUI configuration in tailwind.config.js.

  @mock_members [
    %{id: 1, name: "Adriana Perez", email: "a.perez@example.com", joined: "Jun 2019", address: "8156 Main Ave, San Jose, CA", phone: "(650) 590-3430", status: "Honorific", color: "bg-purple-500"},
    %{id: 2, name: "Adriana Luna", email: "luna.adri@example.com", joined: "Nov 2022", address: "8078 Oak St, Seattle, WA", phone: "(228) 257-5706", status: "Member", color: "bg-blue-500"},
    %{id: 3, name: "Adriana Cruz", email: "cruz.ctrl@example.com", joined: "Oct 2022", address: "5345 Pine Blvd, Austin, TX", phone: "(742) 724-6598", status: "Member", color: "bg-indigo-500"},
    %{id: 4, name: "Adriana Mendez", email: "amendez@example.com", joined: "May 2022", address: "8268 Elm St, Denver, CO", phone: "(399) 698-9842", status: "Member", color: "bg-pink-500"},
    %{id: 5, name: "Adriana Garcia", email: "garcia.a@example.com", joined: "Dec 2020", address: "8285 Pine Ave, Miami, FL", phone: "(887) 213-7200", status: "Member", color: "bg-emerald-500"},
    %{id: 6, name: "Adriana Ortiz", email: "ortiz.ad@example.com", joined: "May 2024", address: "6882 Main Ave, Portland, OR", phone: "(600) 260-9517", status: "Inactive", color: "bg-orange-500"},
    %{id: 7, name: "Adriana Pena", email: "pena.rocks@example.com", joined: "Nov 2022", address: "4450 Main Ln, Chicago, IL", phone: "(783) 240-6887", status: "Member", color: "bg-cyan-500"},
    %{id: 8, name: "Marcus Johnson", email: "marcus.j@example.com", joined: "Jan 2021", address: "1234 Lake Dr, Detroit, MI", phone: "(313) 555-0192", status: "Member", color: "bg-teal-500"}
  ]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:sidebar_open, true)
      |> assign(:active_tab, "Members")
      |> assign(:search_term, "")
      |> assign(:status_filter, "All Statuses")
      |> assign(:selected_rows, MapSet.new())
      |> assign(:members, @mock_members)
      |> assign_filtered_members()

    {:ok, socket}
  end

  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("search", %{"value" => term}, socket) do
    socket
    |> assign(:search_term, term)
    |> assign_filtered_members()
    |> noreply()
  end

  def handle_event("toggle_row", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected_rows

    new_selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else: MapSet.put(selected, id)

    {:noreply, assign(socket, :selected_rows, new_selected)}
  end

  def handle_event("toggle_all", _, socket) do
    all_ids = Enum.map(socket.assigns.filtered_members, & &1.id) |> MapSet.new()
    current_size = MapSet.size(socket.assigns.selected_rows)
    total_size = MapSet.size(all_ids)

    new_selected =
      if current_size == total_size,
        do: MapSet.new(),
        else: all_ids

    {:noreply, assign(socket, :selected_rows, new_selected)}
  end

  defp assign_filtered_members(socket) do
    term = String.downcase(socket.assigns.search_term)
    
    filtered = 
      Enum.filter(socket.assigns.members, fn m -> 
        String.contains?(String.downcase(m.name), term) or 
        String.contains?(String.downcase(m.email), term)
      end)

    assign(socket, :filtered_members, filtered)
  end

  defp noreply(socket), do: {:noreply, socket}

  # --- UI Helper Components (Heex) ---

  def status_badge(assigns) do
    ~H"""
    <div class={
      "badge badge-sm gap-2 p-3 font-medium border-0 " <>
      case @status do
        "Honorific" -> "bg-purple-500/10 text-purple-400"
        "Member" -> "bg-emerald-500/10 text-emerald-400"
        "Inactive" -> "bg-slate-500/10 text-slate-400"
        _ -> "bg-base-content/10 text-base-content/70"
      end
    }>
      <%= @status %>
    </div>
    """
  end

  # --- Main Render ---

  def render(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open font-sans antialiased text-base-content bg-base-300 min-h-screen">
      <input id="app-drawer" type="checkbox" class="drawer-toggle" checked={@sidebar_open} />
      
      <!-- Main Content -->
      <div class="drawer-content flex flex-col">
        <!-- Navbar -->
        <div class="navbar sticky top-0 z-30 bg-base-300/80 backdrop-blur-md border-b border-base-content/5 px-4 lg:px-8 h-16">
          <div class="flex-none lg:hidden">
            <label for="app-drawer" aria-label="open sidebar" class="btn btn-square btn-ghost">
              <.icon name="hero-bars-3" class="w-6 h-6" />
            </label>
          </div>
          
          <div class="flex-1 flex items-center gap-4">
            <button phx-click="toggle_sidebar" class="btn btn-sm btn-square btn-ghost hidden lg:flex">
              <.icon name="hero-view-columns" class="w-5 h-5" />
            </button>
            <div class="text-sm breadcrumbs hidden md:block text-base-content/60">
              <ul>
                <li>Dashboard</li>
                <li class="font-medium text-base-content">Congregants Management</li>
              </ul>
            </div>
          </div>

          <div class="flex-none gap-2">
            <button class="btn btn-ghost btn-circle btn-sm">
              <div class="indicator">
                <.icon name="hero-bell" class="w-5 h-5" />
                <span class="badge badge-xs badge-primary indicator-item border-base-300"></span>
              </div>
            </button>
            <div class="divider divider-horizontal mx-0 h-6"></div>
            <button class="btn btn-ghost btn-circle btn-sm">
              <.icon name="hero-sun" class="w-5 h-5" />
            </button>
          </div>
        </div>

        <!-- Page Content -->
        <div class="p-4 lg:p-8 flex-1 overflow-x-hidden">
          
          <!-- Header Actions -->
          <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-8">
            <div>
              <h1 class="text-2xl font-bold tracking-tight">All Congregants</h1>
              <p class="text-base-content/60 text-sm mt-1">Manage your church members, track attendance and details.</p>
            </div>
            <button class="btn btn-primary shadow-lg shadow-primary/20 gap-2">
              <.icon name="hero-plus" class="w-5 h-5" />
              Add New Congregant
            </button>
          </div>

          <!-- Filters Bar -->
          <div class="bg-base-200 rounded-t-xl border border-base-content/5 p-4 flex flex-col sm:flex-row gap-4 justify-between items-center">
            <div class="relative w-full sm:max-w-md">
              <.icon name="hero-magnifying-glass" class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 opacity-50" />
              <input 
                type="text" 
                placeholder="Search members by name, email..." 
                class="input input-bordered w-full pl-10 bg-base-100 focus:input-primary"
                value={@search_term}
                phx-keyup="search"
                phx-debounce="300"
              />
            </div>
            
            <div class="flex gap-2 w-full sm:w-auto">
              <div class="dropdown dropdown-end">
                <div tabindex="0" role="button" class="btn btn-outline border-base-content/10 bg-base-100 font-normal gap-2 min-w-[140px] justify-between">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-funnel" class="w-4 h-4 opacity-70" />
                    <span><%= @status_filter %></span>
                  </div>
                  <.icon name="hero-chevron-down" class="w-4 h-4 opacity-50" />
                </div>
                <!-- Dropdown content would go here -->
              </div>
              <button class="btn btn-square btn-outline border-base-content/10 bg-base-100 text-base-content/70">
                <.icon name="hero-cog-6-tooth" class="w-5 h-5" />
              </button>
            </div>
          </div>

          <!-- Table Section -->
          <div class="overflow-x-auto bg-base-200 border-x border-b border-base-content/5 rounded-b-xl shadow-xl shadow-base-content/5">
            <table class="table w-full">
              <!-- Head -->
              <thead>
                <tr class="border-b border-base-content/5 bg-base-content/[0.02]">
                  <th class="w-12 py-4 pl-6">
                    <label>
                      <input 
                        type="checkbox" 
                        class="checkbox checkbox-sm checkbox-primary rounded border-base-content/30" 
                        checked={Enum.any?(@filtered_members) && MapSet.size(@selected_rows) == length(@filtered_members)}
                        phx-click="toggle_all"
                      />
                    </label>
                  </th>
                  <th class="text-xs font-semibold uppercase opacity-60 tracking-wider">Member</th>
                  <th class="text-xs font-semibold uppercase opacity-60 tracking-wider">Contact Info</th>
                  <th class="text-xs font-semibold uppercase opacity-60 tracking-wider">Status</th>
                  <th class="text-right text-xs font-semibold uppercase opacity-60 tracking-wider pr-6">Actions</th>
                </tr>
              </thead>
              <tbody>
                <%= for member <- @filtered_members do %>
                  <tr class={"group hover:bg-base-content/[0.02] border-base-content/5 transition-colors " <> if MapSet.member?(@selected_rows, member.id), do: "bg-primary/5", else: ""}>
                    <th class="pl-6">
                      <label>
                        <input 
                          type="checkbox" 
                          class="checkbox checkbox-sm checkbox-primary rounded border-base-content/30"
                          checked={MapSet.member?(@selected_rows, member.id)}
                          phx-click="toggle_row"
                          phx-value-id={member.id}
                        />
                      </label>
                    </th>
                    <td>
                      <div class="flex items-center gap-4">
                        <div class={"avatar placeholder " <> if MapSet.member?(@selected_rows, member.id), do: "online", else: ""}>
                          <div class={"w-10 rounded-full text-white shadow-sm " <> member.color}>
                            <span class="text-sm font-semibold"><%= String.slice(member.name, 0..1) %></span>
                          </div>
                        </div>
                        <div>
                          <div class="font-medium"><%= member.name %></div>
                          <div class="text-xs opacity-50 mt-0.5">Joined <%= member.joined %></div>
                        </div>
                      </div>
                    </td>
                    <td>
                      <div class="space-y-1">
                        <div class="flex items-center gap-2 text-sm opacity-80">
                          <.icon name="hero-map-pin" class="w-3.5 h-3.5 opacity-50" />
                          <%= member.address %>
                        </div>
                        <div class="flex items-center gap-2 text-xs opacity-50">
                          <.icon name="hero-phone" class="w-3 h-3" />
                          <%= member.phone %>
                        </div>
                      </div>
                    </td>
                    <td>
                      <.status_badge status={member.status} />
                    </td>
                    <td class="text-right pr-6">
                      <button class="btn btn-ghost btn-xs btn-square opacity-0 group-hover:opacity-100 transition-opacity">
                        <.icon name="hero-ellipsis-vertical" class="w-4 h-4" />
                      </button>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
            
            <!-- Pagination Footer -->
            <div class="p-4 border-t border-base-content/5 flex items-center justify-between text-sm">
              <span class="opacity-60">Showing <span class="font-medium opacity-100">1</span> to <span class="font-medium opacity-100"><%= length(@filtered_members) %></span> of <%= length(@members) %></span>
              <div class="join">
                <button class="join-item btn btn-sm btn-outline border-base-content/10 font-normal">Previous</button>
                <button class="join-item btn btn-sm btn-active btn-primary text-primary-content">1</button>
                <button class="join-item btn btn-sm btn-outline border-base-content/10 font-normal">2</button>
                <button class="join-item btn btn-sm btn-outline border-base-content/10 font-normal">Next</button>
              </div>
            </div>
          </div>

        </div>
      </div>
      
      <!-- Sidebar Content -->
      <div class="drawer-side z-40">
        <label for="app-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <aside class={"bg-base-100 min-h-full border-r border-base-content/5 flex flex-col transition-all duration-300 " <> if @sidebar_open, do: "w-64", else: "w-20"}>
          <!-- Logo -->
          <div class="h-16 flex items-center px-6 border-b border-base-content/5">
            <div class="flex items-center gap-3">
              <div class="w-8 h-8 bg-gradient-to-br from-primary to-secondary rounded-lg flex items-center justify-center shadow-lg shadow-primary/20">
                <div class="w-3 h-3 bg-white rounded-full opacity-90" />
              </div>
              <span class={"font-bold text-lg tracking-tight transition-opacity duration-200 " <> if !@sidebar_open, do: "hidden"}>
                PACHMS
              </span>
            </div>
          </div>

          <!-- Menu -->
          <div class="flex-1 overflow-y-auto py-6 px-3 custom-scrollbar">
            <div class={"px-3 mb-2 text-xs font-bold opacity-50 uppercase tracking-wider " <> if !@sidebar_open, do: "hidden"}>
              Overview
            </div>
            
            <ul class="menu gap-1 rounded-box">
              <%= for item <- ["Dashboard", "Members", "Contributions", "Ministry Funds", "Calendar"] do %>
                <li>
                  <a phx-click="set_tab" phx-value-tab={item} class={if @active_tab == item, do: "active bg-primary/10 text-primary font-medium"}>
                    <.icon name={
                      case item do
                        "Dashboard" -> "hero-squares-2x2"
                        "Members" -> "hero-users"
                        "Contributions" -> "hero-wallet"
                        "Ministry Funds" -> "hero-heart"
                        "Calendar" -> "hero-calendar"
                      end
                    } class="w-5 h-5" />
                    <span class={if !@sidebar_open, do: "hidden"}><%= item %></span>
                    <%= if item == "Members" and @sidebar_open do %>
                      <span class="badge badge-sm badge-primary badge-outline ml-auto bg-primary/5 border-primary/20 text-primary">
                        <%= length(@members) %>
                      </span>
                    <% end %>
                  </a>
                </li>
              <% end %>
            </ul>
            
            <div class={"mt-6 px-3 mb-2 text-xs font-bold opacity-50 uppercase tracking-wider " <> if !@sidebar_open, do: "hidden"}>
              Administration
            </div>
            <ul class="menu gap-1 rounded-box">
              <%= for item <- ["User Management", "Weekly Reports", "Events", "Family Relations"] do %>
                <li>
                  <a phx-click="set_tab" phx-value-tab={item} class={if @active_tab == item, do: "active bg-primary/10 text-primary font-medium"}>
                    <.icon name={
                      case item do
                        "User Management" -> "hero-cog-6-tooth"
                        "Weekly Reports" -> "hero-document-text"
                        "Events" -> "hero-chart-bar"
                        "Family Relations" -> "hero-heart"
                      end
                    } class="w-5 h-5" />
                    <span class={if !@sidebar_open, do: "hidden"}><%= item %></span>
                  </a>
                </li>
              <% end %>
            </ul>
          </div>

          <!-- User Profile -->
          <div class="p-4 border-t border-base-content/5 mt-auto">
            <button class={"flex items-center gap-3 w-full p-2 rounded-lg hover:bg-base-content/5 transition-colors group text-left " <> if !@sidebar_open, do: "justify-center"}>
              <div class="avatar online">
                <div class="w-10 rounded-full bg-neutral">
                  <img src="https://api.dicebear.com/7.x/avataaars/svg?seed=Felix" />
                </div>
              </div>
              <div class={if !@sidebar_open, do: "hidden", else: "flex-1 overflow-hidden"}>
                <p class="text-sm font-medium truncate group-hover:text-primary transition-colors">Super Admin</p>
                <p class="text-xs opacity-50 truncate">admin@pachms.com</p>
              </div>
              <.icon name="hero-arrow-right-on-rectangle" class={"w-4 h-4 opacity-50 group-hover:text-error " <> if !@sidebar_open, do: "hidden"} />
            </button>
          </div>
        </aside>
      </div>
    </div>
    """
  end
end