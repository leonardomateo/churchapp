defmodule ChurchappWeb.WeekEndingReportsLive.IndexLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.WeekEndingReports

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "Week Ending Reports")
      |> assign(:sort_by, :week_end_date)
      |> assign(:sort_dir, :desc)
      |> assign(:open_menu_id, nil)
      |> assign(:show_delete_confirm, false)
      |> assign(:delete_report_id, nil)
      |> assign(:delete_report_name, nil)
      |> assign(:page, 1)
      |> assign(:per_page, 10)
      |> fetch_reports(actor)

    {:ok, socket}
  end

  defp fetch_reports(socket, actor) do
    reports =
      WeekEndingReports
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.load([:category_entries, :grand_total, :date_range_display])
      |> Ash.Query.sort([{socket.assigns.sort_by, socket.assigns.sort_dir}])
      |> Ash.read!(actor: actor)

    # Pagination
    total_count = length(reports)
    page = socket.assigns.page
    per_page = socket.assigns.per_page

    paginated_reports =
      reports
      |> Enum.drop((page - 1) * per_page)
      |> Enum.take(per_page)

    total_pages = max(ceil(total_count / per_page), 1)

    socket
    |> assign(:reports, paginated_reports)
    |> assign(:total_count, total_count)
    |> assign(:total_pages, total_pages)
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
      |> fetch_reports(actor)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
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

      <%!-- Reports Table --%>
      <div class="bg-dark-800 rounded-lg shadow-xl overflow-x-auto overflow-y-visible border border-dark-700">
        <table class="min-w-full">
          <thead>
            <tr class="border-b border-dark-700">
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
                <td colspan="5" class="px-6 py-12 text-center text-gray-400">
                  <.icon name="hero-document-chart-bar" class="mx-auto h-12 w-12 text-gray-500 mb-4" />
                  <p class="text-lg font-medium">No reports yet</p>
                  <p class="mt-1 text-sm">Create your first week ending report to get started.</p>
                  <.link
                    navigate={~p"/admin/week-ending-reports/new"}
                    class="mt-4 inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md transition-colors"
                  >
                    <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Create Report
                  </.link>
                </td>
              </tr>
            <% else %>
              <tr
                :for={{report, index} <- Enum.with_index(@reports)}
                class="border-b border-dark-700 hover:bg-dark-700/40 transition-all duration-200 group"
              >
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
                    {Calendar.strftime(report.inserted_at, "%b %d, %Y")}
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

      <%!-- Delete Confirmation Modal --%>
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
