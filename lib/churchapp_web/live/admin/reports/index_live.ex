defmodule ChurchappWeb.Admin.ReportsLive.IndexLive do
  @moduledoc """
  Admin LiveView for generating and exporting reports.
  Access is controlled via the router's admin session which requires authentication and admin role.
  """
  use ChurchappWeb, :live_view

  alias Chms.Church.Reports.{ResourceConfig, QueryBuilder}
  alias Chms.Church.Reports.Export.{CsvExport, PdfExport}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Reports")
      |> assign(:available_resources, ResourceConfig.all_resources())
      |> assign(:selected_resource_key, nil)
      |> assign(:selected_resource_config, nil)
      |> assign(:filter_params, %{})
      |> assign(:sort_by, nil)
      |> assign(:sort_dir, :asc)
      |> assign(:page, 1)
      |> assign(:per_page, 25)
      |> assign(:results, [])
      |> assign(:metadata, %{total_count: 0, total_pages: 0})
      |> assign(:loading, false)
      |> assign(:show_export_menu, false)

    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    # Support deep linking with URL params
    socket =
      if resource_key = params["resource"] do
        resource_key_atom = String.to_existing_atom(resource_key)

        socket
        |> assign(:selected_resource_key, resource_key_atom)
        |> load_resource_config(resource_key_atom)
        |> apply_url_params(params)
        |> generate_report()
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("select_resource", %{"resource" => resource_key}, socket) do
    resource_key_atom = String.to_existing_atom(resource_key)
    resource_config = ResourceConfig.get_resource(resource_key_atom)

    socket =
      socket
      |> assign(:selected_resource_key, resource_key_atom)
      |> assign(:selected_resource_config, resource_config)
      |> assign(:filter_params, %{})
      |> assign(:sort_by, elem(resource_config.default_sort, 0))
      |> assign(:sort_dir, elem(resource_config.default_sort, 1))
      |> assign(:page, 1)
      |> assign(:results, [])
      |> assign(:metadata, %{total_count: 0, total_pages: 0})
      |> push_patch(to: ~p"/admin/reports?resource=#{resource_key}")

    {:noreply, socket}
  end

  def handle_event("update_filter", %{"filter" => filter_key, "value" => value}, socket) do
    filter_params = Map.put(socket.assigns.filter_params, filter_key, value)

    socket =
      socket
      |> assign(:filter_params, filter_params)
      |> assign(:page, 1)

    {:noreply, socket}
  end

  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:filter_params, %{})
      |> assign(:page, 1)
      |> generate_report()

    {:noreply, socket}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    field_atom = String.to_existing_atom(field)
    current_sort_by = socket.assigns.sort_by
    current_sort_dir = socket.assigns.sort_dir

    # Toggle direction if clicking same field, otherwise default to :asc
    {new_sort_by, new_sort_dir} =
      if field_atom == current_sort_by do
        {field_atom, if(current_sort_dir == :asc, do: :desc, else: :asc)}
      else
        {field_atom, :asc}
      end

    socket =
      socket
      |> assign(:sort_by, new_sort_by)
      |> assign(:sort_dir, new_sort_dir)
      |> assign(:page, 1)
      |> generate_report()

    {:noreply, socket}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page_int = String.to_integer(page)

    socket =
      socket
      |> assign(:page, page_int)
      |> generate_report()

    {:noreply, socket}
  end

  def handle_event("generate_report", _params, socket) do
    {:noreply, generate_report(socket)}
  end

  def handle_event("export_csv", _params, socket) do
    if socket.assigns.selected_resource_config && length(socket.assigns.results) > 0 do
      csv_content =
        CsvExport.generate(socket.assigns.selected_resource_config, socket.assigns.results)

      filename =
        "#{socket.assigns.selected_resource_config.key}_report_#{Date.utc_today()}.csv"

      socket =
        socket
        |> push_event("download", %{
          content: csv_content,
          filename: filename,
          mime_type: "text/csv"
        })
        |> assign(:show_export_menu, false)

      {:noreply, socket}
    else
      socket =
        socket
        |> put_flash(:error, "No data to export")
        |> assign(:show_export_menu, false)

      {:noreply, socket}
    end
  end

  def handle_event("toggle_export_menu", _params, socket) do
    {:noreply, assign(socket, :show_export_menu, !socket.assigns.show_export_menu)}
  end

  def handle_event("export_pdf", _params, socket) do
    if socket.assigns.selected_resource_config && length(socket.assigns.results) > 0 do
      # Generate HTML for PDF (browser-based approach as fallback)
      html_content =
        PdfExport.generate_html(
          socket.assigns.selected_resource_config,
          socket.assigns.results,
          socket.assigns.filter_params
        )

      # Try to generate PDF binary using wkhtmltopdf
      case PdfExport.generate(
             socket.assigns.selected_resource_config,
             socket.assigns.results,
             socket.assigns.filter_params
           ) do
        {:ok, pdf_binary} ->
          filename =
            "#{socket.assigns.selected_resource_config.key}_report_#{Date.utc_today()}.pdf"

          socket =
            socket
            |> push_event("download", %{
              content: Base.encode64(pdf_binary),
              filename: filename,
              mime_type: "application/pdf",
              is_base64: true
            })
            |> assign(:show_export_menu, false)

          {:noreply, socket}

        {:error, _reason} ->
          # Fallback to browser print-to-PDF
          socket =
            socket
            |> push_event("print_report", %{html: html_content})
            |> assign(:show_export_menu, false)

          {:noreply, socket}
      end
    else
      socket =
        socket
        |> put_flash(:error, "No data to export")
        |> assign(:show_export_menu, false)

      {:noreply, socket}
    end
  end

  def handle_event("print_report", _params, socket) do
    if socket.assigns.selected_resource_config && length(socket.assigns.results) > 0 do
      # Generate print-ready HTML
      html_content =
        PdfExport.generate_html(
          socket.assigns.selected_resource_config,
          socket.assigns.results,
          socket.assigns.filter_params
        )

      socket =
        socket
        |> push_event("print_report", %{html: html_content})
        |> assign(:show_export_menu, false)

      {:noreply, socket}
    else
      socket =
        socket
        |> put_flash(:error, "No data to print")
        |> assign(:show_export_menu, false)

      {:noreply, socket}
    end
  end

  # Private functions

  defp load_resource_config(socket, resource_key) do
    resource_config = ResourceConfig.get_resource(resource_key)
    assign(socket, :selected_resource_config, resource_config)
  end

  defp apply_url_params(socket, params) do
    resource_config = socket.assigns.selected_resource_config

    # Extract filter params from URL
    filter_params =
      Enum.reduce(resource_config.filters, %{}, fn filter, acc ->
        filter_key = to_string(filter.key)

        if value = params[filter_key] do
          Map.put(acc, filter_key, value)
        else
          acc
        end
      end)

    # Extract sort params
    sort_by =
      if params["sort_by"] do
        String.to_existing_atom(params["sort_by"])
      else
        elem(resource_config.default_sort, 0)
      end

    sort_dir =
      if params["sort_dir"] do
        String.to_existing_atom(params["sort_dir"])
      else
        elem(resource_config.default_sort, 1)
      end

    # Extract page
    page =
      if params["page"] do
        String.to_integer(params["page"])
      else
        1
      end

    socket
    |> assign(:filter_params, filter_params)
    |> assign(:sort_by, sort_by)
    |> assign(:sort_dir, sort_dir)
    |> assign(:page, page)
  end

  defp generate_report(socket) do
    if socket.assigns.selected_resource_config do
      socket = assign(socket, :loading, true)

      query_params = %{
        filter_params: socket.assigns.filter_params,
        sort_by: socket.assigns.sort_by,
        sort_dir: socket.assigns.sort_dir,
        page: socket.assigns.page,
        per_page: socket.assigns.per_page
      }

      actor = socket.assigns.current_user

      case QueryBuilder.build_and_execute(
             socket.assigns.selected_resource_config,
             query_params,
             actor
           ) do
        {:ok, results, metadata} ->
          socket
          |> assign(:results, results)
          |> assign(:metadata, metadata)
          |> assign(:loading, false)

        {:error, _error} ->
          socket
          |> put_flash(:error, "Failed to generate report")
          |> assign(:results, [])
          |> assign(:metadata, %{total_count: 0, total_pages: 0})
          |> assign(:loading, false)
      end
    else
      socket
    end
  end

  # Helper functions for template

  def has_active_filters?(filter_params) do
    Enum.any?(filter_params, fn {_key, value} -> value && value != "" end)
  end

  def pagination_range(current_page, total_pages) do
    # Show max 7 page numbers with ellipsis
    cond do
      total_pages <= 7 ->
        Enum.to_list(1..total_pages)

      current_page <= 4 ->
        [1, 2, 3, 4, 5, :ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis | Enum.to_list((total_pages - 4)..total_pages)]

      true ->
        [
          1,
          :ellipsis,
          current_page - 1,
          current_page,
          current_page + 1,
          :ellipsis,
          total_pages
        ]
    end
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active" phx-hook="ReportDownload" id="reports-container">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div class="flex items-center gap-4">
          <h2 class="text-2xl font-bold text-white">Reports</h2>
        </div>
      </div>

      <%!-- Resource Selection --%>
      <div class="mb-6">
        <ChurchappWeb.ReportComponents.resource_selector
          resources={@available_resources}
          selected={@selected_resource_key}
        />
      </div>

      <%= if @selected_resource_config do %>
        <%!-- Filters Panel --%>
        <div class="mb-6">
          <ChurchappWeb.ReportComponents.filters_panel
            resource_config={@selected_resource_config}
            filter_params={@filter_params}
            has_active_filters={has_active_filters?(@filter_params)}
          />
        </div>

        <%!-- Actions Bar --%>
        <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div class="text-sm text-gray-400">
            <%= if @metadata.total_count > 0 do %>
              Showing {(@page - 1) * @per_page + 1} to {min(@page * @per_page, @metadata.total_count)} of {@metadata.total_count} results
            <% else %>
              No results found
            <% end %>
          </div>
          <div class="flex items-center gap-3">
            <button
              type="button"
              phx-click="generate_report"
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
            >
              <.icon name="hero-document-magnifying-glass" class="mr-2 h-4 w-4" /> Generate Report
            </button>

            <%= if length(@results) > 0 do %>
              <div class="relative">
                <button
                  type="button"
                  phx-click="toggle_export_menu"
                  class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded-md hover:bg-dark-700 hover:border-dark-600 transition-colors"
                >
                  <.icon name="hero-arrow-down-tray" class="mr-2 h-4 w-4" /> Export
                </button>

                <%= if @show_export_menu do %>
                  <div class="absolute right-0 mt-2 w-48 bg-dark-800 border border-dark-700 rounded-md shadow-lg z-10 animate-fade-in">
                    <button
                      type="button"
                      phx-click="export_csv"
                      class="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-dark-700 transition-colors flex items-center"
                    >
                      <.icon name="hero-document-text" class="mr-2 h-4 w-4" /> Export as CSV
                    </button>
                    <button
                      type="button"
                      phx-click="export_pdf"
                      class="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-dark-700 transition-colors flex items-center"
                    >
                      <.icon name="hero-document-arrow-down" class="mr-2 h-4 w-4" /> Export as PDF
                    </button>
                    <div class="border-t border-dark-700 my-1"></div>
                    <button
                      type="button"
                      phx-click="print_report"
                      class="w-full text-left px-4 py-2 text-sm text-gray-300 hover:bg-dark-700 transition-colors flex items-center"
                    >
                      <.icon name="hero-printer" class="mr-2 h-4 w-4" /> Print Report
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <%!-- Loading State --%>
        <%= if @loading do %>
          <div class="flex items-center justify-center py-12">
            <ChurchappWeb.ReportComponents.loading_spinner />
          </div>
        <% else %>
          <%!-- Results Table --%>
          <%= if length(@results) > 0 do %>
            <ChurchappWeb.ReportComponents.results_table
              resource_config={@selected_resource_config}
              results={@results}
              sort_by={@sort_by}
              sort_dir={@sort_dir}
            />

            <%!-- Pagination --%>
            <%= if @metadata.total_pages > 1 do %>
              <div class="mt-6">
                <ChurchappWeb.ReportComponents.pagination
                  page={@page}
                  total_pages={@metadata.total_pages}
                  pagination_range={pagination_range(@page, @metadata.total_pages)}
                />
              </div>
            <% end %>
          <% else %>
            <div class="bg-dark-800 border border-dark-700 rounded-lg p-8 text-center">
              <.icon name="hero-document" class="mx-auto h-12 w-12 text-gray-500 mb-3" />
              <p class="text-gray-400">
                <%= if has_active_filters?(@filter_params) do %>
                  No results found matching your filters.
                <% else %>
                  Click "Generate Report" to see results.
                <% end %>
              </p>
              <%= if has_active_filters?(@filter_params) do %>
                <button
                  type="button"
                  phx-click="clear_filters"
                  class="mt-4 inline-flex items-center px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
                >
                  <.icon name="hero-x-mark" class="mr-2 h-4 w-4" /> Clear Filters
                </button>
              <% end %>
            </div>
          <% end %>
        <% end %>
      <% else %>
        <%!-- No Resource Selected State --%>
        <div class="bg-dark-800 border border-dark-700 rounded-lg p-12 text-center">
          <.icon name="hero-chart-bar-square" class="mx-auto h-16 w-16 text-gray-500 mb-4" />
          <h3 class="text-lg font-medium text-white mb-2">Select a Resource</h3>
          <p class="text-gray-400">
            Choose a resource from the dropdown above to begin generating reports.
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
