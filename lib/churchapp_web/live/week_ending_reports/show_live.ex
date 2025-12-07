defmodule ChurchappWeb.WeekEndingReportsLive.ShowLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.ReportCategories

  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns[:current_user]

    case load_report(id, actor) do
      {:ok, report} ->
        entries_by_group = group_entries_by_category(report.category_entries)

        socket =
          socket
          |> assign(:page_title, report.report_name || "Week Ending Report")
          |> assign(:report, report)
          |> assign(:entries_by_group, entries_by_group)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Report not found")
         |> push_navigate(to: ~p"/admin/week-ending-reports")}
    end
  end

  defp load_report(id, actor) do
    Chms.Church.get_week_ending_report_by_id(id,
      actor: actor,
      load: [:grand_total, :date_range_display, category_entries: [:report_category]]
    )
  end

  defp group_entries_by_category(entries) do
    entries
    |> Enum.filter(fn entry ->
      # Only include entries with amount > 0
      entry.report_category && Decimal.compare(entry.amount, Decimal.new(0)) == :gt
    end)
    |> Enum.group_by(fn entry -> entry.report_category.group end)
    |> Enum.sort_by(fn {group, _} ->
      case group do
        :offerings -> 0
        :ministries -> 1
        :missions -> 2
        :property -> 3
        :custom -> 4
        _ -> 5
      end
    end)
  end

  def handle_event("export_csv", _params, socket) do
    report = socket.assigns.report
    entries_by_group = socket.assigns.entries_by_group

    csv_content = generate_csv(report, entries_by_group)

    {:noreply,
     push_event(socket, "download_csv", %{
       content: csv_content,
       filename: "week_ending_report_#{report.week_end_date}.csv"
     })}
  end

  defp generate_csv(report, entries_by_group) do
    lines = [
      "Week Ending Report",
      "Report Name,#{report.report_name || "N/A"}",
      "Date Range,#{report.date_range_display}",
      "Generated,#{Calendar.strftime(DateTime.utc_now(), "%B %d, %Y at %I:%M %p")}",
      "",
      "Category,Group,Amount"
    ]

    entry_lines =
      entries_by_group
      |> Enum.flat_map(fn {group, entries} ->
        entries
        |> Enum.sort_by(fn e -> e.report_category.sort_order end)
        |> Enum.map(fn entry ->
          "\"#{entry.report_category.display_name}\",\"#{ReportCategories.group_display_name(group)}\",#{Decimal.to_string(entry.amount)}"
        end)
      end)

    total_line = [
      "",
      "Grand Total,,#{Decimal.to_string(report.grand_total)}"
    ]

    (lines ++ entry_lines ++ total_line)
    |> Enum.join("\n")
  end

  defp calculate_group_subtotal(entries) do
    entries
    |> Enum.map(& &1.amount)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
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

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/admin/week-ending-reports"}
          class="flex items-center mb-4 text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Reports
        </.link>
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h2 class="text-2xl font-bold text-white">
              {@report.report_name || "Week Ending Report"}
            </h2>
            <p class="mt-1 text-gray-400 flex items-center">
              <.icon name="hero-calendar-days" class="mr-2 h-4 w-4" />
              {@report.date_range_display}
            </p>
          </div>
          <div class="flex items-center space-x-3">
            <button
              type="button"
              phx-click="export_csv"
              phx-hook="CsvDownload"
              id="csv-download-btn"
              class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
            >
              <.icon name="hero-arrow-down-tray" class="mr-2 h-4 w-4" /> Export CSV
            </button>
            <button
              type="button"
              onclick="window.print()"
              class="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
            >
              <.icon name="hero-printer" class="mr-2 h-4 w-4" /> Print
            </button>
            <.link
              navigate={~p"/admin/week-ending-reports/#{@report}/edit"}
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
            >
              <.icon name="hero-pencil-square" class="mr-2 h-4 w-4" /> Edit
            </.link>
          </div>
        </div>
      </div>

      <%!-- Report Content --%>
      <div
        class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden print:shadow-none print:border-gray-300"
        id="report-content"
      >
        <%!-- Print Header (hidden on screen) --%>
        <div class="hidden print:block p-6 border-b border-gray-300">
          <h1 class="text-2xl font-bold text-gray-900">
            {@report.report_name || "Week Ending Report"}
          </h1>
          <p class="text-gray-600">{@report.date_range_display}</p>
        </div>

        <div class="p-6 space-y-6">
          <%!-- Category Groups --%>
          <%= if @entries_by_group == [] do %>
            <div class="text-center py-12">
              <.icon name="hero-document-text" class="mx-auto h-12 w-12 text-gray-500 mb-4" />
              <p class="text-lg font-medium text-gray-400">No entries recorded</p>
              <p class="mt-1 text-sm text-gray-500">This report has no category amounts entered.</p>
            </div>
          <% else %>
            <%= for {group, entries} <- @entries_by_group do %>
              <div class="print:break-inside-avoid">
                <div class="flex items-center justify-between mb-4">
                  <h3 class="flex items-center text-lg font-medium leading-6 text-white print:text-gray-900">
                    <.icon
                      name={ReportCategories.group_icon(group)}
                      class="mr-2 h-5 w-5 text-primary-500 print:text-gray-600"
                    />
                    {ReportCategories.group_display_name(group)}
                  </h3>
                  <span class="text-sm text-gray-400 print:text-gray-600">
                    Subtotal:
                    <span class="font-semibold text-white print:text-gray-900">
                      ${format_currency(calculate_group_subtotal(entries))}
                    </span>
                  </span>
                </div>
                <div class="bg-dark-900/50 print:bg-gray-100 rounded-lg overflow-hidden">
                  <table class="min-w-full">
                    <tbody class="divide-y divide-dark-700 print:divide-gray-200">
                      <%= for entry <- Enum.sort_by(entries, fn e -> e.report_category.sort_order end) do %>
                        <tr class="hover:bg-dark-700/30 print:hover:bg-transparent">
                          <td class="px-4 py-3 text-sm text-gray-300 print:text-gray-700">
                            {entry.report_category.display_name}
                          </td>
                          <td class="px-4 py-3 text-sm text-right font-medium text-white print:text-gray-900">
                            ${format_currency(entry.amount)}
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>
          <% end %>

          <%!-- Notes --%>
          <%= if @report.notes && @report.notes != "" do %>
            <div class="print:break-inside-avoid">
              <h3 class="flex items-center text-lg font-medium leading-6 text-white print:text-gray-900 mb-3">
                <.icon
                  name="hero-document-text"
                  class="mr-2 h-5 w-5 text-primary-500 print:text-gray-600"
                /> Notes
              </h3>
              <div class="p-4 bg-dark-900/50 print:bg-gray-100 rounded-lg">
                <p class="text-gray-300 print:text-gray-700 whitespace-pre-wrap">{@report.notes}</p>
              </div>
            </div>
          <% end %>
        </div>

        <%!-- Grand Total Footer --%>
        <div class="px-6 py-4 bg-dark-700/50 print:bg-gray-200 border-t border-dark-700 print:border-gray-300">
          <div class="flex items-center justify-between">
            <span class="text-lg font-medium text-gray-300 print:text-gray-700">Grand Total</span>
            <span class="text-3xl font-bold text-green-400 print:text-green-600">
              ${format_currency(@report.grand_total)}
            </span>
          </div>
        </div>

        <%!-- Report Metadata --%>
        <div class="px-6 py-3 bg-dark-900/30 print:bg-gray-50 border-t border-dark-700 print:border-gray-200">
          <div class="flex flex-wrap gap-4 text-xs text-gray-500 print:text-gray-600">
            <span>Created: {Calendar.strftime(@report.inserted_at, "%B %d, %Y at %I:%M %p")}</span>
            <%= if @report.updated_at != @report.inserted_at do %>
              <span>
                Last updated: {Calendar.strftime(@report.updated_at, "%B %d, %Y at %I:%M %p")}
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Actions Footer --%>
      <div class="mt-6 flex justify-end print:hidden">
        <.link
          navigate={~p"/admin/week-ending-reports"}
          class="text-gray-400 hover:text-white transition-colors"
        >
          Back to all reports
        </.link>
      </div>
    </div>
    """
  end
end
