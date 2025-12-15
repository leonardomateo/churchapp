defmodule ChurchappWeb.AttendanceLive.ReportsLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Load categories
    categories =
      case Chms.Church.list_active_attendance_categories(actor: actor) do
        {:ok, cats} -> cats
        _ -> []
      end

    # Default date range: last 30 days
    end_date = Date.utc_today()
    start_date = Date.add(end_date, -30)

    socket =
      socket
      |> assign(:page_title, "Attendance Reports")
      |> assign(:categories, categories)
      |> assign(:category_filter, "")
      |> assign(:start_date, Date.to_iso8601(start_date))
      |> assign(:end_date, Date.to_iso8601(end_date))
      |> fetch_report_data()

    {:ok, socket}
  end

  def handle_event("filter_category", %{"category" => category_id}, socket) do
    socket
    |> assign(:category_filter, category_id)
    |> fetch_report_data()
    |> then(&{:noreply, &1})
  end

  def handle_event("update_start_date", %{"start_date" => date}, socket) do
    socket
    |> assign(:start_date, date)
    |> fetch_report_data()
    |> then(&{:noreply, &1})
  end

  def handle_event("update_end_date", %{"end_date" => date}, socket) do
    socket
    |> assign(:end_date, date)
    |> fetch_report_data()
    |> then(&{:noreply, &1})
  end

  def handle_event("export_csv", _params, socket) do
    csv_data = generate_csv(socket.assigns.sessions)

    {:noreply,
     push_event(socket, "download", %{
       filename: "attendance_report_#{socket.assigns.start_date}_#{socket.assigns.end_date}.csv",
       content: csv_data
     })}
  end

  defp fetch_report_data(socket) do
    actor = socket.assigns[:current_user]

    query =
      Chms.Church.AttendanceSessions
      |> Ash.Query.sort(session_datetime: :desc)
      |> Ash.Query.load(:category)

    # Apply date filter
    query =
      with {:ok, start_date} <- Date.from_iso8601(socket.assigns.start_date),
           {:ok, end_date} <- Date.from_iso8601(socket.assigns.end_date) do
        Ash.Query.filter(
          query,
          fragment("?::date", session_datetime) >= ^start_date and
            fragment("?::date", session_datetime) <= ^end_date
        )
      else
        _ -> query
      end

    # Apply category filter
    query =
      if socket.assigns.category_filter != "" do
        Ash.Query.filter(query, category_id == ^socket.assigns.category_filter)
      else
        query
      end

    case Ash.read(query, actor: actor) do
      {:ok, sessions} ->
        # Calculate statistics
        stats = calculate_statistics(sessions, socket.assigns.categories)

        socket
        |> assign(:sessions, sessions)
        |> assign(:stats, stats)

      {:error, _} ->
        socket
        |> assign(:sessions, [])
        |> assign(:stats, %{
          total_sessions: 0,
          total_attendance: 0,
          average_attendance: 0,
          by_category: [],
          by_day_of_week: []
        })
        |> put_flash(:error, "Failed to load report data")
    end
  end

  defp calculate_statistics(sessions, categories) do
    total_sessions = length(sessions)
    total_attendance = sessions |> Enum.map(& &1.total_present) |> Enum.sum()

    average_attendance =
      if total_sessions > 0 do
        Float.round(total_attendance / total_sessions, 1)
      else
        0
      end

    # Group by category
    by_category =
      sessions
      |> Enum.group_by(& &1.category_id)
      |> Enum.map(fn {category_id, cat_sessions} ->
        category = Enum.find(categories, fn c -> c.id == category_id end)
        cat_total = cat_sessions |> Enum.map(& &1.total_present) |> Enum.sum()
        cat_count = length(cat_sessions)
        cat_avg = if cat_count > 0, do: Float.round(cat_total / cat_count, 1), else: 0

        %{
          category: category,
          sessions: cat_count,
          total: cat_total,
          average: cat_avg
        }
      end)
      |> Enum.sort_by(& &1.total, :desc)

    # Group by day of week
    by_day_of_week =
      sessions
      |> Enum.group_by(fn s ->
        DateTime.to_date(s.session_datetime) |> Date.day_of_week()
      end)
      |> Enum.map(fn {day, day_sessions} ->
        day_total = day_sessions |> Enum.map(& &1.total_present) |> Enum.sum()
        day_count = length(day_sessions)
        day_avg = if day_count > 0, do: Float.round(day_total / day_count, 1), else: 0

        %{
          day: day,
          day_name: day_name(day),
          sessions: day_count,
          total: day_total,
          average: day_avg
        }
      end)
      |> Enum.sort_by(& &1.day)

    %{
      total_sessions: total_sessions,
      total_attendance: total_attendance,
      average_attendance: average_attendance,
      by_category: by_category,
      by_day_of_week: by_day_of_week
    }
  end

  defp day_name(1), do: "Monday"
  defp day_name(2), do: "Tuesday"
  defp day_name(3), do: "Wednesday"
  defp day_name(4), do: "Thursday"
  defp day_name(5), do: "Friday"
  defp day_name(6), do: "Saturday"
  defp day_name(7), do: "Sunday"

  defp generate_csv(sessions) do
    header = "Date,Day,Time,Category,Attendance\n"

    rows =
      sessions
      |> Enum.map(fn s ->
        date = DateTime.to_date(s.session_datetime) |> Date.to_iso8601()
        day = DateTime.to_date(s.session_datetime) |> Date.day_of_week() |> day_name()
        time = Calendar.strftime(s.session_datetime, "%I:%M %p")
        category = s.category.name
        attendance = s.total_present

        "#{date},#{day},#{time},#{category},#{attendance}"
      end)
      |> Enum.join("\n")

    header <> rows
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active" id="reports-container" phx-hook="DownloadCSV">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div>
          <h2 class="text-2xl font-bold text-white">Attendance Reports</h2>
          <p class="mt-1 text-sm text-gray-400">
            View attendance statistics and trends
          </p>
        </div>
        <.link
          navigate={~p"/attendance"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Attendance
        </.link>
      </div>

      <%!-- Filters --%>
      <div class="mb-6 flex flex-col sm:flex-row gap-4 items-end">
        <div class="flex-1 max-w-xs">
          <label class="block text-xs font-medium text-gray-400 mb-1">Category</label>
          <select
            phx-change="filter_category"
            name="category"
            value={@category_filter}
            class="w-full px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent cursor-pointer"
          >
            <option value="">All Categories</option>
            <option :for={category <- @categories} value={category.id}>
              {category.name}
            </option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-400 mb-1">Start Date</label>
          <input
            type="date"
            phx-change="update_start_date"
            name="start_date"
            value={@start_date}
            class="px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-400 mb-1">End Date</label>
          <input
            type="date"
            phx-change="update_end_date"
            name="end_date"
            value={@end_date}
            class="px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
          />
        </div>
        <button
          type="button"
          phx-click="export_csv"
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
        >
          <.icon name="hero-arrow-down-tray" class="mr-2 h-4 w-4" /> Export CSV
        </button>
      </div>

      <%!-- Stats Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-400">Total Sessions</p>
              <p class="text-3xl font-bold text-white mt-1">{@stats.total_sessions}</p>
            </div>
            <div class="p-3 bg-blue-500/10 rounded-full">
              <.icon name="hero-clipboard-document-list" class="h-6 w-6 text-blue-400" />
            </div>
          </div>
        </div>
        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-400">Total Attendance</p>
              <p class="text-3xl font-bold text-white mt-1">{@stats.total_attendance}</p>
            </div>
            <div class="p-3 bg-green-500/10 rounded-full">
              <.icon name="hero-users" class="h-6 w-6 text-green-400" />
            </div>
          </div>
        </div>
        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-400">Average per Session</p>
              <p class="text-3xl font-bold text-white mt-1">{@stats.average_attendance}</p>
            </div>
            <div class="p-3 bg-primary-500/10 rounded-full">
              <.icon name="hero-chart-bar" class="h-6 w-6 text-primary-400" />
            </div>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <%!-- By Category --%>
        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <h3 class="text-lg font-semibold text-white mb-4">By Category</h3>
          <div class="space-y-4">
            <div
              :for={item <- @stats.by_category}
              class="flex items-center"
            >
              <div
                class="w-3 h-3 rounded-full mr-3 flex-shrink-0"
                style={"background-color: #{item.category.color};"}
              >
              </div>
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between mb-1">
                  <span class="text-sm font-medium text-white truncate">
                    {item.category.name}
                  </span>
                  <span class="text-sm text-gray-400 ml-2">
                    {item.total} total
                  </span>
                </div>
                <div class="flex items-center text-xs text-gray-500">
                  <span>{item.sessions} sessions</span>
                  <span class="mx-2">•</span>
                  <span>Avg: {item.average}</span>
                </div>
              </div>
            </div>
            <div :if={@stats.by_category == []} class="py-4 text-center text-gray-500">
              No data available
            </div>
          </div>
        </div>

        <%!-- By Day of Week --%>
        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <h3 class="text-lg font-semibold text-white mb-4">By Day of Week</h3>
          <div class="space-y-3">
            <div
              :for={item <- @stats.by_day_of_week}
              class="flex items-center"
            >
              <div class="w-24 text-sm font-medium text-gray-300">{item.day_name}</div>
              <div class="flex-1 mx-4">
                <div class="h-4 bg-dark-700 rounded-full overflow-hidden">
                  <div
                    class="h-full bg-primary-500 rounded-full transition-all duration-500"
                    style={"width: #{calculate_bar_width(item.total, @stats.by_day_of_week)}%;"}
                  >
                  </div>
                </div>
              </div>
              <div class="w-20 text-right">
                <span class="text-sm font-medium text-white">{item.total}</span>
                <span class="text-xs text-gray-500 ml-1">({item.sessions})</span>
              </div>
            </div>
            <div :if={@stats.by_day_of_week == []} class="py-4 text-center text-gray-500">
              No data available
            </div>
          </div>
        </div>
      </div>

      <%!-- Sessions Table --%>
      <div class="mt-6 bg-dark-800 rounded-lg border border-dark-700 overflow-hidden">
        <div class="px-6 py-4 border-b border-dark-700">
          <h3 class="text-lg font-semibold text-white">Session Details</h3>
        </div>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-dark-700">
            <thead class="bg-dark-700/50">
              <tr>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Date
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Day
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Category
                </th>
                <th
                  scope="col"
                  class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider"
                >
                  Attendance
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-dark-700">
              <tr
                :for={session <- @sessions}
                class="hover:bg-dark-700/40 transition-colors cursor-pointer"
                phx-click={JS.navigate(~p"/attendance/#{session.id}")}
              >
                <td class="px-6 py-4 whitespace-nowrap text-sm text-white">
                  {Calendar.strftime(session.session_datetime, "%b %d, %Y")}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-400">
                  {Calendar.strftime(session.session_datetime, "%A")}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="flex items-center">
                    <div
                      class="w-2 h-2 rounded-full mr-2"
                      style={"background-color: #{session.category.color};"}
                    >
                    </div>
                    <span class="text-sm text-gray-300">{session.category.name}</span>
                  </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium text-white">
                  {session.total_present}
                </td>
              </tr>
              <tr :if={@sessions == []}>
                <td colspan="4" class="px-6 py-12 text-center text-gray-500">
                  No sessions found for the selected date range
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp calculate_bar_width(value, all_items) do
    max_value = all_items |> Enum.map(& &1.total) |> Enum.max(fn -> 1 end)
    if max_value > 0, do: value / max_value * 100, else: 0
  end
end
