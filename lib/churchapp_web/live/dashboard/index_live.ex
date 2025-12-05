defmodule ChurchappWeb.DashboardLive.IndexLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Statistics

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:loading, true)
      |> fetch_statistics(actor)

    {:ok, socket}
  end

  defp fetch_statistics(socket, actor) do
    # Fetch congregant statistics
    {:ok, total_congregants} = Statistics.get_total_congregants(actor)
    {:ok, active_members} = Statistics.get_active_members_count(actor)
    {:ok, visitors_count} = Statistics.get_visitors_count(actor)
    {:ok, honorific_count} = Statistics.get_honorific_count(actor)
    {:ok, deceased_count} = Statistics.get_deceased_count(actor)
    {:ok, status_stats} = Statistics.get_congregant_counts_by_status(actor)
    {:ok, country_stats} = Statistics.get_congregant_counts_by_country(actor)

    # Fetch contribution statistics
    {:ok, total_contributions} = Statistics.get_total_contributions(actor)
    {:ok, total_revenue} = Statistics.get_total_revenue(actor)
    {:ok, contribution_type_stats} = Statistics.get_contribution_counts_by_type(actor)
    {:ok, revenue_by_type_stats} = Statistics.get_revenue_by_type(actor)

    socket
    |> assign(:loading, false)
    |> assign(:total_congregants, total_congregants)
    |> assign(:active_members, active_members)
    |> assign(:visitors_count, visitors_count)
    |> assign(:honorific_count, honorific_count)
    |> assign(:deceased_count, deceased_count)
    |> assign(:status_stats, status_stats)
    |> assign(:status_stats_json, Jason.encode!(status_stats))
    |> assign(:country_stats, country_stats)
    |> assign(:country_stats_json, Jason.encode!(country_stats))
    |> assign(:total_contributions, total_contributions)
    |> assign(:total_revenue, total_revenue)
    |> assign(:contribution_type_stats, contribution_type_stats)
    |> assign(:contribution_type_stats_json, Jason.encode!(contribution_type_stats))
    |> assign(:revenue_by_type_stats, revenue_by_type_stats)
    |> assign(:revenue_by_type_stats_json, Jason.encode!(revenue_by_type_stats))
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6">
        <h2 class="text-2xl font-bold text-white">Statistics Dashboard</h2>
        <p class="text-gray-400 mt-1">Overview of congregants and contributions</p>
      </div>

      <%!-- Summary Stat Cards --%>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <%!-- Total Congregants Card - Always show --%>
        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                Total Members
              </p>
              <p class="text-3xl font-bold text-white mt-2">
                {@total_congregants}
              </p>
            </div>
            <div class="p-3 bg-primary-500/10 rounded-lg">
              <.icon name="hero-users" class="h-8 w-8 text-primary-500" />
            </div>
          </div>
        </div>

        <%!-- Active Members Card - Only show if count > 0 --%>
        <%= if @active_members > 0 do %>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Active Members
                </p>
                <p class="text-3xl font-bold text-white mt-2">
                  {@active_members}
                </p>
              </div>
              <div class="p-3 bg-green-500/10 rounded-lg">
                <.icon name="hero-check-circle" class="h-8 w-8 text-green-400" />
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Visitors Card - Only show if count > 0 --%>
        <%= if @visitors_count > 0 do %>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Visitors
                </p>
                <p class="text-3xl font-bold text-white mt-2">
                  {@visitors_count}
                </p>
              </div>
              <div class="p-3 bg-yellow-500/10 rounded-lg">
                <.icon name="hero-user-plus" class="h-8 w-8 text-yellow-400" />
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Honorific Card - Only show if count > 0 --%>
        <%= if @honorific_count > 0 do %>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Honorific
                </p>
                <p class="text-3xl font-bold text-white mt-2">
                  {@honorific_count}
                </p>
              </div>
              <div class="p-3 bg-blue-500/10 rounded-lg">
                <.icon name="hero-star" class="h-8 w-8 text-blue-400" />
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Deceased Card - Only show if count > 0 --%>
        <%= if @deceased_count > 0 do %>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Deceased
                </p>
                <p class="text-3xl font-bold text-white mt-2">
                  {@deceased_count}
                </p>
              </div>
              <div class="p-3 bg-gray-500/10 rounded-lg">
                <.icon name="hero-heart" class="h-8 w-8 text-gray-400" />
              </div>
            </div>
          </div>
        <% end %>

        <%!-- Total Contributions Card - Always show --%>
        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                Total Contributions
              </p>
              <p class="text-3xl font-bold text-white mt-2">
                {@total_contributions}
              </p>
            </div>
            <div class="p-3 bg-purple-500/10 rounded-lg">
              <.icon name="hero-document-text" class="h-8 w-8 text-purple-400" />
            </div>
          </div>
        </div>

        <%!-- Total Revenue Card - Always show --%>
        <div class="stat-card">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                Total Revenue
              </p>
              <p class="text-3xl font-bold text-white mt-2">
                ${format_currency(@total_revenue)}
              </p>
            </div>
            <div class="p-3 bg-emerald-500/10 rounded-lg">
              <.icon name="hero-banknotes" class="h-8 w-8 text-emerald-400" />
            </div>
          </div>
        </div>
      </div>

      <%!-- Congregant Statistics Section --%>
      <div class="mb-8">
        <h3 class="text-xl font-semibold text-white mb-4 flex items-center">
          <.icon name="hero-users" class="mr-2 h-6 w-6 text-primary-500" /> Congregant Statistics
        </h3>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Status Distribution Chart --%>
          <div class="chart-container">
            <h4 class="text-lg font-medium text-white mb-4">Member Status Distribution</h4>
            <canvas
              id="status-chart"
              phx-hook="DoughnutChart"
              data-chart-data={@status_stats_json}
              data-chart-title="Status Distribution"
            >
            </canvas>
          </div>

          <%!-- Country Distribution Chart --%>
          <div class="chart-container">
            <h4 class="text-lg font-medium text-white mb-4">Top 10 Countries</h4>
            <canvas
              id="country-chart"
              phx-hook="BarChart"
              data-chart-data={@country_stats_json}
              data-chart-title="Country Distribution"
              data-chart-horizontal="true"
            >
            </canvas>
          </div>
        </div>
      </div>

      <%!-- Contribution Statistics Section --%>
      <div class="mb-8">
        <h3 class="text-xl font-semibold text-white mb-4 flex items-center">
          <.icon name="hero-banknotes" class="mr-2 h-6 w-6 text-primary-500" />
          Contribution Statistics
        </h3>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Contribution Type Count Chart --%>
          <div class="chart-container">
            <h4 class="text-lg font-medium text-white mb-4">Contributions by Type</h4>
            <canvas
              id="contribution-type-chart"
              phx-hook="PieChart"
              data-chart-data={@contribution_type_stats_json}
              data-chart-title="Contribution Types"
            >
            </canvas>
          </div>

          <%!-- Revenue by Type Chart --%>
          <div class="chart-container">
            <h4 class="text-lg font-medium text-white mb-4">Revenue by Type</h4>
            <canvas
              id="revenue-type-chart"
              phx-hook="BarChart"
              data-chart-data={@revenue_by_type_stats_json}
              data-chart-title="Revenue by Type"
              data-chart-currency="true"
            >
            </canvas>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_currency(decimal) do
    decimal
    |> Decimal.to_string(:normal)
    |> String.split(".")
    |> case do
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
