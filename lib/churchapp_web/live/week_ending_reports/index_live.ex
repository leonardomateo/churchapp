defmodule ChurchappWeb.WeekEndingReportsLive.IndexLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.WeekEndingReports

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Fetch all reports for the filter dropdown
    all_reports = fetch_all_reports(actor)

    socket =
      socket
      |> assign(:page_title, "Week Ending Reports")
      |> assign(:sort_by, :week_end_date)
      |> assign(:sort_dir, :desc)
      |> assign(:filter_report_id, nil)
      |> assign(:all_reports_for_filter, all_reports)
      |> assign(:open_menu_id, nil)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:show_bulk_delete_confirm, false)
      |> assign(:show_delete_confirm, false)
      |> assign(:delete_report_id, nil)
      |> assign(:delete_report_name, nil)
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> fetch_reports(actor)

    {:ok, socket}
  end

  defp fetch_all_reports(actor) do
    WeekEndingReports
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.load([:date_range_display])
    |> Ash.Query.sort(week_end_date: :desc)
    |> Ash.read!(actor: actor)
  end

  defp fetch_reports(socket, actor) do
    reports =
      WeekEndingReports
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.load([:category_entries, :grand_total, :date_range_display])
      |> Ash.Query.sort([{socket.assigns.sort_by, socket.assigns.sort_dir}])
      |> Ash.read!(actor: actor)

    # Apply filters
    filtered_reports = filter_by_report_id(reports, socket.assigns.filter_report_id)

    # Pagination
    total_count = length(filtered_reports)
    page = socket.assigns.page
    per_page = socket.assigns.per_page

    paginated_reports =
      filtered_reports
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)

    total_pages = max(ceil(total_count / per_page), 1)

    socket
    |> assign(:reports, paginated_reports)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
  end

  defp filter_by_report_id(reports, nil), do: reports
  defp filter_by_report_id(reports, ""), do: reports

  defp filter_by_report_id(reports, report_id) do
    Enum.filter(reports, fn report ->
      report.id == report_id
    end)
  end

  defp has_active_filters?(assigns) do
    assigns.filter_report_id != nil and assigns.filter_report_id != ""
  end

  defp get_selected_report_display(assigns) do
    if assigns.filter_report_id do
      Enum.find(assigns.all_reports_for_filter, fn r -> r.id == assigns.filter_report_id end)
    else
      nil
    end
  end

  def handle_event("filter_report", %{"filter_report_id" => report_id}, socket) do
    actor = socket.assigns[:current_user]

    filter_id = if report_id == "", do: nil, else: report_id

    socket =
      socket
      |> assign(:filter_report_id, filter_id)
      |> assign(:page, 1)
      |> fetch_reports(actor)

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    actor = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:filter_report_id, nil)
      |> assign(:page, 1)
      |> fetch_reports(actor)

    {:noreply, socket}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)
    actor = socket.assigns[:current_user]

    {sort_by, sort_dir} =
      if socket.assigns.sort_by == field do
        {field, if(socket.assigns.sort_dir == :asc, do: :desc, else: :asc)}
      else
        {field, :asc}
      end

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)
      |> assign(:page, 1)
      |> fetch_reports(actor)

    {:noreply, socket}
  end

  def handle_event("toggle_menu", %{"id" => id}, socket) do
    new_id = if socket.assigns.open_menu_id == id, do: nil, else: id
    {:noreply, assign(socket, :open_menu_id, new_id)}
  end

  def handle_event("close_menu", _params, socket) do
    {:noreply, assign(socket, :open_menu_id, nil)}
  end

  def handle_event("show_delete_confirm", %{"id" => id, "name" => name}, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_confirm, true)
     |> assign(:delete_report_id, id)
     |> assign(:delete_report_name, name)
     |> assign(:open_menu_id, nil)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_confirm, false)
     |> assign(:delete_report_id, nil)
     |> assign(:delete_report_name, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    actor = socket.assigns[:current_user]
    report_id = socket.assigns.delete_report_id

    case Chms.Church.get_week_ending_report_by_id(report_id, actor: actor) do
      {:ok, report} ->
        case Ash.destroy(report, actor: actor) do
          :ok ->
            {:noreply,
             socket
             |> put_flash(:info, "Report deleted successfully")
             |> assign(:show_delete_confirm, false)
             |> assign(:delete_report_id, nil)
             |> assign(:delete_report_name, nil)
             |> fetch_reports(actor)}

          {:error, _} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to delete report")
             |> assign(:show_delete_confirm, false)}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Report not found")
         |> assign(:show_delete_confirm, false)}
    end
  end

  def handle_event("change_page", %{"page" => page}, socket) do
    actor = socket.assigns[:current_user]
    page = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page)
      |> assign(:selected_ids, MapSet.new())
      |> fetch_reports(actor)

    {:noreply, socket}
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
    all_ids = Enum.map(socket.assigns.reports, & &1.id) |> MapSet.new()

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

  def handle_event("show_bulk_delete_confirm", _params, socket) do
    {:noreply, assign(socket, :show_bulk_delete_confirm, true)}
  end

  def handle_event("cancel_bulk_delete", _params, socket) do
    {:noreply, assign(socket, :show_bulk_delete_confirm, false)}
  end

  def handle_event("confirm_bulk_delete", _params, socket) do
    actor = socket.assigns.current_user
    count = MapSet.size(socket.assigns.selected_ids)

    Enum.each(socket.assigns.selected_ids, fn id ->
      case Chms.Church.get_week_ending_report_by_id(id, actor: actor) do
        {:ok, report} -> Ash.destroy(report, actor: actor)
        _ -> :ok
      end
    end)

    socket
    |> put_flash(:info, "Successfully deleted #{count} report(s)")
    |> assign(:selected_ids, MapSet.new())
    |> assign(:show_bulk_delete_confirm, false)
    |> fetch_reports(actor)
    |> then(&{:noreply, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
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
                phx-click="show_bulk_delete_confirm"
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-full transition-colors"
              >
                <.icon name="hero-trash" class="mr-2 h-4 w-4" /> Delete Selected
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Page Header --%>
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div>
          <h2 class="text-2xl font-bold text-white">Week Ending Reports</h2>
          <p class="mt-1 text-gray-400">Manage weekly financial reports</p>
        </div>
        <.link
          navigate={~p"/admin/week-ending-reports/new"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-plus" class="mr-2 h-4 w-4" /> New Report
        </.link>
      </div>

      <%!-- Filters --%>
      <div class="mb-6 bg-dark-800 rounded-lg border border-dark-700 p-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%!-- Report Dropdown Filter --%>
          <div class="md:col-span-1">
            <label for="filter_report_id" class="block text-sm font-medium text-gray-400 mb-1">
              Select Report
            </label>
            <form phx-change="filter_report">
              <select
                id="filter_report_id"
                name="filter_report_id"
                class="block w-full h-[38px] px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
              >
                <option value="">All Reports</option>
                <%= for report <- @all_reports_for_filter do %>
                  <option value={report.id} selected={@filter_report_id == report.id}>
                    {report.report_name || "Untitled"} - {report.date_range_display}
                  </option>
                <% end %>
              </select>
            </form>
          </div>

          <%!-- Clear Filters Button --%>
          <div class="md:col-span-1 flex items-end">
            <%= if has_active_filters?(assigns) do %>
              <button
                type="button"
                phx-click="clear_filters"
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
              >
                <.icon name="hero-x-mark" class="mr-2 h-4 w-4" /> Clear Filter
              </button>
            <% else %>
              <div class="text-sm text-gray-500 py-2">
                <.icon name="hero-funnel" class="inline h-4 w-4 mr-1" /> No filter applied
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Active Filter Summary --%>
        <%= if has_active_filters?(assigns) do %>
          <% selected_report = get_selected_report_display(assigns) %>
          <div class="mt-4 pt-4 border-t border-dark-700">
            <div class="flex flex-wrap items-center gap-2">
              <span class="text-sm text-gray-400">Active filter:</span>
              <%= if selected_report do %>
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-500/10 text-blue-400 border border-blue-500/20">
                  Report: {selected_report.report_name || "Untitled"} ({selected_report.date_range_display})
                </span>
              <% end %>
              <span class="text-sm text-gray-500">
                ({@total_count} {if @total_count == 1, do: "result", else: "results"})
              </span>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Reports Table --%>
      <div class="bg-dark-800 rounded-lg shadow-xl overflow-x-auto overflow-y-visible border border-dark-700">
        <table class="min-w-full">
          <thead>
            <tr class="border-b border-dark-700">
              <th scope="col" class="px-6 py-4 w-12">
                <input
                  type="checkbox"
                  phx-click="toggle_select_all"
                  checked={
                    MapSet.size(@selected_ids) > 0 &&
                      MapSet.size(@selected_ids) == length(@reports)
                  }
                  class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                  aria-label="Select all"
                />
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-white transition-colors"
                phx-click="sort"
                phx-value-field="report_name"
              >
                <div class="flex items-center">
                  Report Name
                  <%= if @sort_by == :report_name do %>
                    <.icon
                      name={if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"}
                      class="ml-1 h-4 w-4"
                    />
                  <% end %>
                </div>
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-white transition-colors"
                phx-click="sort"
                phx-value-field="week_end_date"
              >
                <div class="flex items-center">
                  Date Range
                  <%= if @sort_by == :week_end_date do %>
                    <.icon
                      name={if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"}
                      class="ml-1 h-4 w-4"
                    />
                  <% end %>
                </div>
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
              >
                Grand Total
              </th>
              <th
                scope="col"
                class="px-6 py-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:text-white transition-colors"
                phx-click="sort"
                phx-value-field="inserted_at"
              >
                <div class="flex items-center">
                  Created
                  <%= if @sort_by == :inserted_at do %>
                    <.icon
                      name={if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"}
                      class="ml-1 h-4 w-4"
                    />
                  <% end %>
                </div>
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
            <%= if @reports == [] do %>
              <tr>
                <td colspan="6" class="px-6 py-12 text-center text-gray-400">
                  <.icon name="hero-document-chart-bar" class="mx-auto h-12 w-12 text-gray-500 mb-4" />
                  <%= if has_active_filters?(assigns) do %>
                    <p class="text-lg font-medium">No reports found</p>
                    <p class="mt-1 text-sm">Try adjusting your search or filter criteria.</p>
                    <button
                      type="button"
                      phx-click="clear_filters"
                      class="mt-4 inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md transition-colors"
                    >
                      <.icon name="hero-x-mark" class="mr-2 h-4 w-4" /> Clear Filters
                    </button>
                  <% else %>
                    <p class="text-lg font-medium">No reports yet</p>
                    <p class="mt-1 text-sm">Create your first week ending report to get started.</p>
                    <.link
                      navigate={~p"/admin/week-ending-reports/new"}
                      class="mt-4 inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md transition-colors"
                    >
                      <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Create Report
                    </.link>
                  <% end %>
                </td>
              </tr>
            <% else %>
              <tr
                :for={{report, index} <- Enum.with_index(@reports)}
                class={[
                  "border-b border-dark-700 hover:bg-dark-700/40 transition-all duration-200 group",
                  MapSet.member?(@selected_ids, report.id) && "bg-primary-900/20"
                ]}
              >
                <td class="px-6 py-5 w-12">
                  <input
                    type="checkbox"
                    phx-click="toggle_select"
                    phx-value-id={report.id}
                    checked={MapSet.member?(@selected_ids, report.id)}
                    class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500 focus:ring-offset-dark-800 cursor-pointer"
                    aria-label={"Select #{report.report_name || "report"}"}
                  />
                </td>
                <td
                  class="px-6 py-5 cursor-pointer"
                  phx-click={JS.navigate(~p"/admin/week-ending-reports/#{report}")}
                >
                  <div class="flex items-center">
                    <div class="p-2 bg-primary-500/10 rounded-lg mr-3">
                      <.icon name="hero-document-chart-bar" class="h-5 w-5 text-primary-500" />
                    </div>
                    <div>
                      <p class="font-medium text-white group-hover:text-primary-400 transition-colors">
                        {report.report_name || "Untitled Report"}
                      </p>
                    </div>
                  </div>
                </td>
                <td
                  class="px-6 py-5 cursor-pointer"
                  phx-click={JS.navigate(~p"/admin/week-ending-reports/#{report}")}
                >
                  <div class="text-sm text-gray-300">
                    {report.date_range_display}
                  </div>
                </td>
                <td
                  class="px-6 py-5 text-right cursor-pointer"
                  phx-click={JS.navigate(~p"/admin/week-ending-reports/#{report}")}
                >
                  <span class="text-lg font-semibold text-green-400">
                    ${format_currency(report.grand_total)}
                  </span>
                </td>
                <td
                  class="px-6 py-5 cursor-pointer"
                  phx-click={JS.navigate(~p"/admin/week-ending-reports/#{report}")}
                >
                  <div class="text-sm text-gray-400">
                    <span
                      id={"report-created-#{report.id}"}
                      phx-hook="LocalTime"
                      data-utc={DateTime.to_iso8601(report.inserted_at)}
                      data-format="datetime"
                    >
                      {Calendar.strftime(report.inserted_at, "%b %d, %Y at %I:%M %p")}
                    </span>
                  </div>
                </td>
                <td class="px-6 py-5 text-right">
                  <div class="flex items-center justify-end relative">
                    <button
                      type="button"
                      phx-click="toggle_menu"
                      phx-value-id={report.id}
                      class="p-2 text-gray-400 hover:text-white rounded-md hover:bg-dark-700 transition-colors"
                    >
                      <.icon name="hero-ellipsis-vertical" class="h-5 w-5" />
                    </button>

                    <%= if @open_menu_id == report.id do %>
                      <div
                        phx-click-away="close_menu"
                        class={[
                          "absolute right-0 w-48 rounded-md shadow-lg bg-dark-700 ring-1 ring-dark-600 z-50",
                          if(index >= length(@reports) - 2,
                            do: "bottom-full mb-2",
                            else: "top-full mt-2"
                          )
                        ]}
                      >
                        <div class="py-1" role="menu">
                          <.link
                            navigate={~p"/admin/week-ending-reports/#{report}"}
                            class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                          >
                            <.icon name="hero-eye" class="mr-3 h-4 w-4" /> View Details
                          </.link>
                          <.link
                            navigate={~p"/admin/week-ending-reports/#{report}/edit"}
                            class="flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-600 hover:text-white transition-colors"
                          >
                            <.icon name="hero-pencil-square" class="mr-3 h-4 w-4" /> Edit
                          </.link>
                          <button
                            type="button"
                            phx-click="show_delete_confirm"
                            phx-value-id={report.id}
                            phx-value-name={report.report_name || "this report"}
                            class="flex w-full items-center px-4 py-2 text-sm text-red-400 hover:bg-dark-600 hover:text-red-300 transition-colors"
                          >
                            <.icon name="hero-trash" class="mr-3 h-4 w-4" /> Delete
                          </button>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>

        <%!-- Pagination --%>
        <%= if @total_count > 0 do %>
          <div class="px-6 py-4 flex flex-col sm:flex-row items-center justify-between gap-4 bg-dark-800 border-t border-dark-700">
            <div class="text-sm text-gray-500">
              Showing {(@page - 1) * @per_page + 1} to {min(@page * @per_page, @total_count)} of {@total_count} reports
            </div>
            <div class="flex items-center gap-2">
              <button
                type="button"
                phx-click="change_page"
                phx-value-page={@page - 1}
                disabled={@page <= 1}
                class="px-3 py-1 text-sm text-gray-300 bg-dark-700 rounded-md hover:bg-dark-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Previous
              </button>

              <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                <button
                  type="button"
                  phx-click="change_page"
                  phx-value-page={page_num}
                  class={[
                    "px-3 py-1 text-sm rounded-md transition-colors",
                    if(page_num == @page,
                      do: "bg-primary-500 text-white",
                      else: "text-gray-300 bg-dark-700 hover:bg-dark-600"
                    )
                  ]}
                >
                  {page_num}
                </button>
              <% end %>

              <button
                type="button"
                phx-click="change_page"
                phx-value-page={@page + 1}
                disabled={@page >= @total_pages}
                class="px-3 py-1 text-sm text-gray-300 bg-dark-700 rounded-md hover:bg-dark-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
              >
                Next
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <%!-- Single Delete Confirmation Modal --%>
      <%= if @show_delete_confirm do %>
        <div
          class="fixed inset-0 z-[100] overflow-y-auto"
          role="dialog"
          aria-modal="true"
          phx-window-keydown="cancel_delete"
          phx-key="escape"
        >
          <div class="fixed inset-0 modal-backdrop transition-opacity" phx-click="cancel_delete">
          </div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-md">
              <div class="p-6">
                <div class="flex items-center justify-center w-12 h-12 mx-auto bg-red-500/10 rounded-full mb-4">
                  <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                </div>
                <h3 class="text-lg font-semibold text-white text-center mb-2">Delete Report</h3>
                <p class="text-gray-400 text-center mb-6">
                  Are you sure you want to delete "{@delete_report_name}"? This action cannot be undone.
                </p>
                <div class="flex justify-center space-x-3">
                  <button
                    type="button"
                    phx-click="cancel_delete"
                    class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_delete"
                    class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700 transition-colors"
                  >
                    Delete Report
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%!-- Bulk Delete Confirmation Modal --%>
      <%= if @show_bulk_delete_confirm do %>
        <div
          class="fixed inset-0 z-[100] overflow-y-auto"
          role="dialog"
          aria-modal="true"
          phx-window-keydown="cancel_bulk_delete"
          phx-key="escape"
        >
          <div class="fixed inset-0 modal-backdrop transition-opacity" phx-click="cancel_bulk_delete">
          </div>
          <div class="flex min-h-full items-center justify-center p-4">
            <div class="relative transform overflow-hidden rounded-lg bg-dark-800 border border-dark-700 shadow-2xl transition-all w-full max-w-md">
              <div class="p-6">
                <div class="flex items-center justify-center w-12 h-12 mx-auto bg-red-500/10 rounded-full mb-4">
                  <.icon name="hero-exclamation-triangle" class="h-6 w-6 text-red-500" />
                </div>
                <h3 class="text-lg font-semibold text-white text-center mb-2">Delete Reports</h3>
                <p class="text-gray-400 text-center mb-6">
                  Are you sure you want to delete {MapSet.size(@selected_ids)} report(s)? This action cannot be undone.
                </p>
                <div class="flex justify-center space-x-3">
                  <button
                    type="button"
                    phx-click="cancel_bulk_delete"
                    class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    phx-click="confirm_bulk_delete"
                    class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700 transition-colors"
                  >
                    Delete Reports
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp format_currency(nil), do: "0.00"

  defp format_currency(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> format_with_commas()
  end

  defp format_with_commas(number_string) do
    case String.split(number_string, ".") do
      [whole] ->
        format_whole_number(whole) <> ".00"

      [whole, decimal_part] ->
        format_whole_number(whole) <> "." <> String.pad_trailing(decimal_part, 2, "0")
    end
  end

  defp format_whole_number(number_string) do
    number_string
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
