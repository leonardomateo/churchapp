defmodule ChurchappWeb.Admin.ReportsLive.ComparisonLive do
  @moduledoc """
  Admin LiveView for period-over-period comparison reports.
  Allows comparing data between two date ranges side by side.
  """
  use ChurchappWeb, :live_view

  alias Chms.Church.Reports.{ResourceConfig, QueryBuilder}

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Comparison Reports")
      |> assign(:available_resources, ResourceConfig.all_resources())
      |> assign(:selected_resource_key, nil)
      |> assign(:selected_resource_config, nil)
      |> assign(:filter_params, %{})
      # Period 1
      |> assign(:period1_start, nil)
      |> assign(:period1_end, nil)
      |> assign(:period1_results, [])
      |> assign(:period1_metadata, %{total_count: 0})
      # Period 2
      |> assign(:period2_start, nil)
      |> assign(:period2_end, nil)
      |> assign(:period2_results, [])
      |> assign(:period2_metadata, %{total_count: 0})
      # Comparison data
      |> assign(:comparison_data, nil)
      |> assign(:loading, false)

    {:ok, socket}
  end

  def handle_event("select_resource", %{"resource" => resource_key}, socket) do
    resource_key_atom = String.to_existing_atom(resource_key)
    resource_config = ResourceConfig.get_resource(resource_key_atom)

    socket =
      socket
      |> assign(:selected_resource_key, resource_key_atom)
      |> assign(:selected_resource_config, resource_config)
      |> assign(:filter_params, %{})
      |> assign(:period1_results, [])
      |> assign(:period1_metadata, %{total_count: 0})
      |> assign(:period2_results, [])
      |> assign(:period2_metadata, %{total_count: 0})
      |> assign(:comparison_data, nil)

    {:noreply, socket}
  end

  def handle_event("update_period1_start", %{"value" => value}, socket) do
    {:noreply, assign(socket, :period1_start, parse_date(value))}
  end

  def handle_event("update_period1_end", %{"value" => value}, socket) do
    {:noreply, assign(socket, :period1_end, parse_date(value))}
  end

  def handle_event("update_period2_start", %{"value" => value}, socket) do
    {:noreply, assign(socket, :period2_start, parse_date(value))}
  end

  def handle_event("update_period2_end", %{"value" => value}, socket) do
    {:noreply, assign(socket, :period2_end, parse_date(value))}
  end

  def handle_event("update_filter", params, socket) do
    filter_key = params["filter"]
    value = params["value"]

    if filter_key do
      filter_params = Map.put(socket.assigns.filter_params, filter_key, value)
      {:noreply, assign(socket, :filter_params, filter_params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply, assign(socket, :filter_params, %{})}
  end

  def handle_event("generate_comparison", _params, socket) do
    if valid_periods?(socket) do
      socket =
        socket
        |> assign(:loading, true)
        |> generate_comparison()

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Please select valid date ranges for both periods")}
    end
  end

  def handle_event("set_preset_periods", %{"preset" => preset}, socket) do
    {period1_start, period1_end, period2_start, period2_end} = get_preset_periods(preset)

    socket =
      socket
      |> assign(:period1_start, period1_start)
      |> assign(:period1_end, period1_end)
      |> assign(:period2_start, period2_start)
      |> assign(:period2_end, period2_end)

    {:noreply, socket}
  end

  # Private functions

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp valid_periods?(socket) do
    socket.assigns.period1_start && socket.assigns.period1_end &&
      socket.assigns.period2_start && socket.assigns.period2_end &&
      socket.assigns.selected_resource_config
  end

  defp generate_comparison(socket) do
    resource_config = socket.assigns.selected_resource_config
    actor = socket.assigns.current_user

    # Build date filter params for each period
    date_field = get_date_field(resource_config)

    period1_filter_params =
      Map.merge(socket.assigns.filter_params, %{
        "#{date_field}_from" => Date.to_iso8601(socket.assigns.period1_start),
        "#{date_field}_to" => Date.to_iso8601(socket.assigns.period1_end)
      })

    period2_filter_params =
      Map.merge(socket.assigns.filter_params, %{
        "#{date_field}_from" => Date.to_iso8601(socket.assigns.period2_start),
        "#{date_field}_to" => Date.to_iso8601(socket.assigns.period2_end)
      })

    # Fetch data for both periods (larger page size for aggregation)
    period1_params = %{filter_params: period1_filter_params, page: 1, per_page: 10000}
    period2_params = %{filter_params: period2_filter_params, page: 1, per_page: 10000}

    period1_result = QueryBuilder.build_and_execute(resource_config, period1_params, actor)
    period2_result = QueryBuilder.build_and_execute(resource_config, period2_params, actor)

    case {period1_result, period2_result} do
      {{:ok, results1, metadata1}, {:ok, results2, metadata2}} ->
        comparison_data = calculate_comparison(results1, results2, resource_config)

        socket
        |> assign(:period1_results, results1)
        |> assign(:period1_metadata, metadata1)
        |> assign(:period2_results, results2)
        |> assign(:period2_metadata, metadata2)
        |> assign(:comparison_data, comparison_data)
        |> assign(:loading, false)

      _ ->
        socket
        |> put_flash(:error, "Failed to fetch comparison data")
        |> assign(:loading, false)
    end
  end

  defp get_date_field(resource_config) do
    # Find the primary date field for the resource
    case resource_config.key do
      :contributions -> "date"
      :ministry_funds -> "date"
      :week_ending_reports -> "week_start"
      :events -> "start"
      :congregants -> "member_since"
      _ -> "date"
    end
  end

  defp calculate_comparison(results1, results2, resource_config) do
    # Calculate aggregates for numeric fields
    numeric_fields =
      resource_config.fields
      |> Enum.filter(&(&1.type in [:currency, :integer, :decimal, :float]))

    field_comparisons =
      Enum.map(numeric_fields, fn field ->
        sum1 = calculate_sum(results1, field.key)
        sum2 = calculate_sum(results2, field.key)

        difference = Decimal.sub(sum1, sum2)
        percent_change = calculate_percent_change(sum1, sum2)

        %{
          field: field,
          period1_sum: sum1,
          period2_sum: sum2,
          difference: difference,
          percent_change: percent_change
        }
      end)

    %{
      period1_count: length(results1),
      period2_count: length(results2),
      count_difference: length(results1) - length(results2),
      count_percent_change:
        calculate_percent_change(
          Decimal.new(length(results1)),
          Decimal.new(length(results2))
        ),
      field_comparisons: field_comparisons
    }
  end

  defp calculate_sum(results, field_key) do
    Enum.reduce(results, Decimal.new(0), fn item, acc ->
      case Map.get(item, field_key) do
        %Decimal{} = d -> Decimal.add(acc, d)
        n when is_number(n) -> Decimal.add(acc, Decimal.from_float(n / 1))
        _ -> acc
      end
    end)
  end

  defp calculate_percent_change(current, previous) do
    cond do
      Decimal.equal?(previous, Decimal.new(0)) && Decimal.equal?(current, Decimal.new(0)) ->
        Decimal.new(0)

      Decimal.equal?(previous, Decimal.new(0)) ->
        Decimal.new(100)

      true ->
        current
        |> Decimal.sub(previous)
        |> Decimal.div(previous)
        |> Decimal.mult(100)
        |> Decimal.round(2)
    end
  end

  defp get_preset_periods(preset) do
    today = Date.utc_today()

    case preset do
      "this_vs_last_month" ->
        this_month_start = Date.beginning_of_month(today)
        this_month_end = Date.end_of_month(today)
        last_month_end = Date.add(this_month_start, -1)
        last_month_start = Date.beginning_of_month(last_month_end)
        {this_month_start, this_month_end, last_month_start, last_month_end}

      "this_vs_last_quarter" ->
        {current_quarter, _} = quarter_dates(today)
        {prev_quarter, _} = quarter_dates(Date.add(elem(current_quarter, 0), -1))

        {elem(current_quarter, 0), elem(current_quarter, 1), elem(prev_quarter, 0),
         elem(prev_quarter, 1)}

      "this_vs_last_year" ->
        this_year_start = Date.new!(today.year, 1, 1)
        this_year_end = Date.new!(today.year, 12, 31)
        last_year_start = Date.new!(today.year - 1, 1, 1)
        last_year_end = Date.new!(today.year - 1, 12, 31)
        {this_year_start, this_year_end, last_year_start, last_year_end}

      "ytd_comparison" ->
        this_year_start = Date.new!(today.year, 1, 1)
        last_year_start = Date.new!(today.year - 1, 1, 1)
        last_year_same_day = Date.new!(today.year - 1, today.month, today.day)
        {this_year_start, today, last_year_start, last_year_same_day}

      _ ->
        {nil, nil, nil, nil}
    end
  end

  defp quarter_dates(date) do
    quarter =
      cond do
        date.month in 1..3 -> 1
        date.month in 4..6 -> 2
        date.month in 7..9 -> 3
        true -> 4
      end

    {start_month, end_month} =
      case quarter do
        1 -> {1, 3}
        2 -> {4, 6}
        3 -> {7, 9}
        4 -> {10, 12}
      end

    start_date = Date.new!(date.year, start_month, 1)
    end_date = Date.end_of_month(Date.new!(date.year, end_month, 1))
    {{start_date, end_date}, quarter}
  end

  # Helper functions for template

  defp format_decimal(nil, _type), do: "-"

  defp format_decimal(%Decimal{} = value, :currency) do
    "$#{Decimal.round(value, 2) |> Decimal.to_string(:normal)}"
  end

  defp format_decimal(%Decimal{} = value, _type) do
    Decimal.round(value, 2) |> Decimal.to_string(:normal)
  end

  defp format_percent(%Decimal{} = value) do
    formatted = Decimal.round(value, 1) |> Decimal.to_string(:normal)
    "#{formatted}%"
  end

  defp change_indicator(%Decimal{} = value) do
    cond do
      Decimal.positive?(value) -> :increase
      Decimal.negative?(value) -> :decrease
      true -> :neutral
    end
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active" id="comparison-reports-container">
      <div class="mb-6 flex flex-col sm:flex-row justify-between items-start sm:items-center space-y-4 sm:space-y-0">
        <div class="flex items-center gap-4">
          <.link
            navigate={~p"/admin/reports"}
            class="text-gray-400 hover:text-white transition-colors"
          >
            <.icon name="hero-arrow-left" class="h-5 w-5" />
          </.link>
          <h2 class="text-2xl font-bold text-white">Comparison Reports</h2>
        </div>
      </div>

      <%!-- Resource Selection --%>
      <div class="mb-6">
        <form phx-change="select_resource" class="w-full sm:w-auto">
          <select
            name="resource"
            class="w-full sm:w-64 px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
          >
            <option value="">Select a Resource...</option>
            <%= for resource <- @available_resources do %>
              <option value={resource.key} selected={resource.key == @selected_resource_key}>
                {resource.name}
              </option>
            <% end %>
          </select>
        </form>
      </div>

      <%= if @selected_resource_config do %>
        <%!-- Period Selection --%>
        <div class="mb-6 grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Period 1 --%>
          <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
            <h3 class="text-sm font-medium text-white flex items-center mb-4">
              <.icon name="hero-calendar" class="mr-2 h-4 w-4 text-primary-500" /> Period 1 (Current)
            </h3>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1">Start Date</label>
                <form phx-change="update_period1_start">
                  <input
                    type="date"
                    name="value"
                    value={@period1_start && Date.to_iso8601(@period1_start)}
                    class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </form>
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1">End Date</label>
                <form phx-change="update_period1_end">
                  <input
                    type="date"
                    name="value"
                    value={@period1_end && Date.to_iso8601(@period1_end)}
                    class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </form>
              </div>
            </div>
          </div>

          <%!-- Period 2 --%>
          <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
            <h3 class="text-sm font-medium text-white flex items-center mb-4">
              <.icon name="hero-calendar-days" class="mr-2 h-4 w-4 text-amber-500" />
              Period 2 (Previous)
            </h3>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1">Start Date</label>
                <form phx-change="update_period2_start">
                  <input
                    type="date"
                    name="value"
                    value={@period2_start && Date.to_iso8601(@period2_start)}
                    class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </form>
              </div>
              <div>
                <label class="block text-xs font-medium text-gray-400 mb-1">End Date</label>
                <form phx-change="update_period2_end">
                  <input
                    type="date"
                    name="value"
                    value={@period2_end && Date.to_iso8601(@period2_end)}
                    class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </form>
              </div>
            </div>
          </div>
        </div>

        <%!-- Preset Buttons --%>
        <div class="mb-6 flex flex-wrap gap-2">
          <span class="text-sm text-gray-400 mr-2 self-center">Quick Presets:</span>
          <button
            type="button"
            phx-click="set_preset_periods"
            phx-value-preset="this_vs_last_month"
            class="px-3 py-1.5 text-xs font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded hover:bg-dark-700 hover:border-dark-600 transition-colors"
          >
            This vs Last Month
          </button>
          <button
            type="button"
            phx-click="set_preset_periods"
            phx-value-preset="this_vs_last_quarter"
            class="px-3 py-1.5 text-xs font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded hover:bg-dark-700 hover:border-dark-600 transition-colors"
          >
            This vs Last Quarter
          </button>
          <button
            type="button"
            phx-click="set_preset_periods"
            phx-value-preset="this_vs_last_year"
            class="px-3 py-1.5 text-xs font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded hover:bg-dark-700 hover:border-dark-600 transition-colors"
          >
            This vs Last Year
          </button>
          <button
            type="button"
            phx-click="set_preset_periods"
            phx-value-preset="ytd_comparison"
            class="px-3 py-1.5 text-xs font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded hover:bg-dark-700 hover:border-dark-600 transition-colors"
          >
            YTD Comparison
          </button>
        </div>

        <%!-- Generate Button --%>
        <div class="mb-6">
          <button
            type="button"
            phx-click="generate_comparison"
            disabled={@loading}
            class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors disabled:opacity-50"
          >
            <%= if @loading do %>
              <svg
                class="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
                fill="none"
                viewBox="0 0 24 24"
              >
                <circle
                  class="opacity-25"
                  cx="12"
                  cy="12"
                  r="10"
                  stroke="currentColor"
                  stroke-width="4"
                >
                </circle>
                <path
                  class="opacity-75"
                  fill="currentColor"
                  d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                >
                </path>
              </svg>
              Generating...
            <% else %>
              <.icon name="hero-arrows-right-left" class="mr-2 h-4 w-4" /> Generate Comparison
            <% end %>
          </button>
        </div>

        <%!-- Comparison Results --%>
        <%= if @comparison_data do %>
          <div class="space-y-6">
            <%!-- Summary Cards --%>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <%!-- Period 1 Count --%>
              <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
                <div class="text-sm text-gray-400 mb-1">Period 1 Records</div>
                <div class="text-2xl font-bold text-white">{@comparison_data.period1_count}</div>
                <div class="text-xs text-gray-500 mt-1">
                  {@period1_start && Date.to_string(@period1_start)} to {@period1_end &&
                    Date.to_string(@period1_end)}
                </div>
              </div>

              <%!-- Period 2 Count --%>
              <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
                <div class="text-sm text-gray-400 mb-1">Period 2 Records</div>
                <div class="text-2xl font-bold text-white">{@comparison_data.period2_count}</div>
                <div class="text-xs text-gray-500 mt-1">
                  {@period2_start && Date.to_string(@period2_start)} to {@period2_end &&
                    Date.to_string(@period2_end)}
                </div>
              </div>

              <%!-- Change --%>
              <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
                <div class="text-sm text-gray-400 mb-1">Record Change</div>
                <div class={[
                  "text-2xl font-bold flex items-center gap-2",
                  cond do
                    @comparison_data.count_difference > 0 -> "text-green-400"
                    @comparison_data.count_difference < 0 -> "text-red-400"
                    true -> "text-gray-400"
                  end
                ]}>
                  <%= if @comparison_data.count_difference > 0 do %>
                    <.icon name="hero-arrow-trending-up" class="h-6 w-6" />
                    +{@comparison_data.count_difference}
                  <% else %>
                    <%= if @comparison_data.count_difference < 0 do %>
                      <.icon name="hero-arrow-trending-down" class="h-6 w-6" />
                      {@comparison_data.count_difference}
                    <% else %>
                      <.icon name="hero-minus" class="h-6 w-6" /> 0
                    <% end %>
                  <% end %>
                </div>
                <div class={[
                  "text-xs mt-1",
                  cond do
                    change_indicator(@comparison_data.count_percent_change) == :increase ->
                      "text-green-400"

                    change_indicator(@comparison_data.count_percent_change) == :decrease ->
                      "text-red-400"

                    true ->
                      "text-gray-500"
                  end
                ]}>
                  {format_percent(@comparison_data.count_percent_change)}
                </div>
              </div>
            </div>

            <%!-- Field Comparisons Table --%>
            <%= if length(@comparison_data.field_comparisons) > 0 do %>
              <div class="bg-dark-800 border border-dark-700 rounded-lg overflow-hidden">
                <div class="px-6 py-4 border-b border-dark-700">
                  <h3 class="text-sm font-medium text-white">Field Comparisons</h3>
                </div>
                <div class="overflow-x-auto">
                  <table class="min-w-full divide-y divide-dark-700">
                    <thead class="bg-dark-900">
                      <tr>
                        <th
                          scope="col"
                          class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider"
                        >
                          Field
                        </th>
                        <th
                          scope="col"
                          class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider"
                        >
                          Period 1
                        </th>
                        <th
                          scope="col"
                          class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider"
                        >
                          Period 2
                        </th>
                        <th
                          scope="col"
                          class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider"
                        >
                          Difference
                        </th>
                        <th
                          scope="col"
                          class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider"
                        >
                          Change %
                        </th>
                      </tr>
                    </thead>
                    <tbody class="bg-dark-800 divide-y divide-dark-700">
                      <%= for comparison <- @comparison_data.field_comparisons do %>
                        <tr class="hover:bg-dark-700 transition-colors">
                          <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-200">
                            {comparison.field.label}
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-right text-gray-300">
                            {format_decimal(comparison.period1_sum, comparison.field.type)}
                          </td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-right text-gray-300">
                            {format_decimal(comparison.period2_sum, comparison.field.type)}
                          </td>
                          <td class={[
                            "px-6 py-4 whitespace-nowrap text-sm text-right font-medium",
                            cond do
                              change_indicator(comparison.difference) == :increase -> "text-green-400"
                              change_indicator(comparison.difference) == :decrease -> "text-red-400"
                              true -> "text-gray-400"
                            end
                          ]}>
                            <%= if Decimal.positive?(comparison.difference) do %>
                              +{format_decimal(comparison.difference, comparison.field.type)}
                            <% else %>
                              {format_decimal(comparison.difference, comparison.field.type)}
                            <% end %>
                          </td>
                          <td class={[
                            "px-6 py-4 whitespace-nowrap text-sm text-right",
                            cond do
                              change_indicator(comparison.percent_change) == :increase ->
                                "text-green-400"

                              change_indicator(comparison.percent_change) == :decrease ->
                                "text-red-400"

                              true ->
                                "text-gray-400"
                            end
                          ]}>
                            <div class="flex items-center justify-end gap-1">
                              <%= cond do %>
                                <% change_indicator(comparison.percent_change) == :increase -> %>
                                  <.icon name="hero-arrow-trending-up" class="h-4 w-4" />
                                <% change_indicator(comparison.percent_change) == :decrease -> %>
                                  <.icon name="hero-arrow-trending-down" class="h-4 w-4" />
                                <% true -> %>
                                  <.icon name="hero-minus" class="h-4 w-4" />
                              <% end %>
                              {format_percent(comparison.percent_change)}
                            </div>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="bg-dark-800 border border-dark-700 rounded-lg p-8 text-center">
            <.icon name="hero-arrows-right-left" class="mx-auto h-12 w-12 text-gray-500 mb-3" />
            <p class="text-gray-400">
              Select date ranges for both periods and click "Generate Comparison" to see results.
            </p>
          </div>
        <% end %>
      <% else %>
        <%!-- No Resource Selected State --%>
        <div class="bg-dark-800 border border-dark-700 rounded-lg p-12 text-center">
          <.icon name="hero-arrows-right-left" class="mx-auto h-16 w-16 text-gray-500 mb-4" />
          <h3 class="text-lg font-medium text-white mb-2">Select a Resource</h3>
          <p class="text-gray-400">
            Choose a resource from the dropdown above to compare data between two periods.
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
