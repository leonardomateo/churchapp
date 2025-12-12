defmodule ChurchappWeb.ReportChartComponents do
  @moduledoc """
  Reusable chart components for the reports interface.
  Leverages existing Chart.js hooks (BarChart, PieChart, DoughnutChart).
  """
  use Phoenix.Component
  import ChurchappWeb.CoreComponents

  @doc """
  View mode toggle to switch between table and chart views.
  """
  attr :view_mode, :atom, required: true

  def view_mode_toggle(assigns) do
    ~H"""
    <div class="flex items-center bg-dark-800 border border-dark-700 rounded-lg p-1">
      <button
        type="button"
        phx-click="toggle_view"
        phx-value-mode="table"
        class={[
          "px-3 py-1.5 text-sm font-medium rounded-md transition-colors flex items-center gap-2",
          if(@view_mode == :table,
            do: "bg-primary-500 text-white shadow-lg shadow-primary-500/20",
            else: "text-gray-400 hover:text-white hover:bg-dark-700"
          )
        ]}
      >
        <.icon name="hero-table-cells" class="h-4 w-4" />
        <span class="hidden sm:inline">Table</span>
      </button>
      <button
        type="button"
        phx-click="toggle_view"
        phx-value-mode="chart"
        class={[
          "px-3 py-1.5 text-sm font-medium rounded-md transition-colors flex items-center gap-2",
          if(@view_mode == :chart,
            do: "bg-primary-500 text-white shadow-lg shadow-primary-500/20",
            else: "text-gray-400 hover:text-white hover:bg-dark-700"
          )
        ]}
      >
        <.icon name="hero-chart-bar" class="h-4 w-4" />
        <span class="hidden sm:inline">Chart</span>
      </button>
    </div>
    """
  end

  @doc """
  Chart type selector dropdown.
  """
  attr :charts, :list, required: true
  attr :selected_chart, :atom, required: true

  def chart_selector(assigns) do
    ~H"""
    <div class="flex items-center gap-3">
      <label class="text-sm font-medium text-gray-400">Chart Type:</label>
      <form phx-change="select_chart" class="flex-1 sm:flex-none">
        <select
          name="chart"
          class="w-full sm:w-auto px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
        >
          <%= for chart <- @charts do %>
            <option value={chart.key} selected={chart.key == @selected_chart}>
              {chart.name}
            </option>
          <% end %>
        </select>
      </form>
    </div>
    """
  end

  @doc """
  Chart display container with the selected chart type.
  """
  attr :chart_config, :map, required: true
  attr :chart_data_json, :string, required: true
  attr :chart_id, :string, default: "report-chart"

  def chart_display(assigns) do
    ~H"""
    <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
      <div class="mb-4">
        <h3 class="text-lg font-medium text-white">{@chart_config.name}</h3>
        <%= if Map.get(@chart_config, :description) do %>
          <p class="text-sm text-gray-400 mt-1">{@chart_config.description}</p>
        <% end %>
      </div>

      <div class="relative" style="min-height: 300px; max-height: 500px;">
        <%= case @chart_config.type do %>
          <% :pie -> %>
            <canvas
              id={@chart_id}
              phx-hook="PieChart"
              data-chart-data={@chart_data_json}
              data-chart-title={@chart_config.name}
              phx-update="ignore"
              class="max-w-md mx-auto"
            >
            </canvas>
          <% :doughnut -> %>
            <canvas
              id={@chart_id}
              phx-hook="DoughnutChart"
              data-chart-data={@chart_data_json}
              data-chart-title={@chart_config.name}
              phx-update="ignore"
              class="max-w-md mx-auto"
            >
            </canvas>
          <% :bar -> %>
            <canvas
              id={@chart_id}
              phx-hook="BarChart"
              data-chart-data={@chart_data_json}
              data-chart-title={@chart_config.name}
              data-chart-horizontal={to_string(Map.get(@chart_config, :horizontal, false))}
              data-chart-currency={to_string(Map.get(@chart_config, :currency, false))}
              phx-update="ignore"
            >
            </canvas>
          <% _ -> %>
            <div class="flex items-center justify-center h-64 text-gray-400">
              Unsupported chart type
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Chart info panel showing summary statistics.
  """
  attr :chart_data, :list, required: true
  attr :chart_config, :map, required: true

  def chart_stats(assigns) do
    total =
      Enum.reduce(assigns.chart_data, 0, fn item, acc ->
        value = item.value

        cond do
          is_struct(value, Decimal) -> Decimal.add(acc, value) |> Decimal.to_float()
          is_number(value) -> acc + value
          true -> acc
        end
      end)

    max_item = Enum.max_by(assigns.chart_data, & &1.value, fn -> %{label: "N/A", value: 0} end)
    item_count = length(assigns.chart_data)
    is_currency = Map.get(assigns.chart_config, :currency, false)

    assigns =
      assigns
      |> assign(:total, total)
      |> assign(:max_item, max_item)
      |> assign(:item_count, item_count)
      |> assign(:is_currency, is_currency)

    ~H"""
    <div class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-4">
      <div class="bg-dark-900 border border-dark-700 rounded-lg p-4">
        <p class="text-xs font-medium text-gray-500 uppercase tracking-wider">Total</p>
        <p class="mt-1 text-lg font-semibold text-white">
          <%= if @is_currency do %>
            ${format_number(@total)}
          <% else %>
            {format_number(@total)}
          <% end %>
        </p>
      </div>
      <div class="bg-dark-900 border border-dark-700 rounded-lg p-4">
        <p class="text-xs font-medium text-gray-500 uppercase tracking-wider">Categories</p>
        <p class="mt-1 text-lg font-semibold text-white">{@item_count}</p>
      </div>
      <div class="bg-dark-900 border border-dark-700 rounded-lg p-4">
        <p class="text-xs font-medium text-gray-500 uppercase tracking-wider">Largest</p>
        <p class="mt-1 text-lg font-semibold text-white truncate" title={@max_item.label}>
          {truncate_label(@max_item.label)}
        </p>
      </div>
      <div class="bg-dark-900 border border-dark-700 rounded-lg p-4">
        <p class="text-xs font-medium text-gray-500 uppercase tracking-wider">Largest Value</p>
        <p class="mt-1 text-lg font-semibold text-white">
          <%= if @is_currency do %>
            ${format_number(@max_item.value)}
          <% else %>
            {format_number(@max_item.value)}
          <% end %>
        </p>
      </div>
    </div>
    """
  end

  @doc """
  Empty chart state when no data is available.
  """
  def empty_chart_state(assigns) do
    ~H"""
    <div class="bg-dark-800 border border-dark-700 rounded-lg p-12 text-center">
      <.icon name="hero-chart-bar" class="mx-auto h-12 w-12 text-gray-500 mb-3" />
      <h3 class="text-lg font-medium text-white mb-2">No Chart Data</h3>
      <p class="text-gray-400">
        Generate a report first to view chart visualizations.
      </p>
    </div>
    """
  end

  @doc """
  Chart view container with selector and display.
  """
  attr :resource_config, :map, required: true
  attr :selected_chart, :atom, required: true
  attr :chart_data, :list, required: true
  attr :chart_data_json, :string, required: true

  def chart_view(assigns) do
    charts = Map.get(assigns.resource_config, :charts, [])
    chart_config = Enum.find(charts, List.first(charts), &(&1.key == assigns.selected_chart))

    assigns =
      assigns
      |> assign(:charts, charts)
      |> assign(:chart_config, chart_config)

    ~H"""
    <div class="space-y-6">
      <%= if length(@charts) > 1 do %>
        <.chart_selector charts={@charts} selected_chart={@selected_chart} />
      <% end %>

      <%= if @chart_config && length(@chart_data) > 0 do %>
        <.chart_display
          chart_config={@chart_config}
          chart_data_json={@chart_data_json}
          chart_id={"report-chart-#{@chart_config.key}"}
        />
        <.chart_stats chart_data={@chart_data} chart_config={@chart_config} />
      <% else %>
        <.empty_chart_state />
      <% end %>
    </div>
    """
  end

  # Helper functions

  defp format_number(value) when is_float(value) do
    value
    |> Float.round(2)
    |> :erlang.float_to_binary(decimals: 2)
  end

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)

  defp format_number(%Decimal{} = value) do
    value
    |> Decimal.to_float()
    |> format_number()
  end

  defp format_number(value), do: to_string(value)

  defp truncate_label(nil), do: "N/A"
  defp truncate_label(label) when is_atom(label), do: label |> to_string() |> truncate_label()
  defp truncate_label(label) when is_boolean(label), do: if(label, do: "Yes", else: "No")

  defp truncate_label(label) when is_binary(label) do
    if String.length(label) > 15 do
      String.slice(label, 0, 12) <> "..."
    else
      label
    end
  end

  defp truncate_label(label), do: to_string(label)
end
