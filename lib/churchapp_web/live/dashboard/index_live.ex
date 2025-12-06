defmodule ChurchappWeb.DashboardLive.IndexLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Statistics

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Get current month name for display
    current_month = Date.utc_today() |> Calendar.strftime("%B %Y")

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:loading, true)
      |> assign(:current_month, current_month)
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

    # Fetch ministry funds statistics
    {:ok, ministry_revenue} = Statistics.get_total_ministry_revenue(actor)
    {:ok, ministry_expenses} = Statistics.get_total_ministry_expenses(actor)
    {:ok, ministry_balance} = Statistics.get_ministry_net_balance(actor)
    {:ok, ministry_transaction_count} = Statistics.get_ministry_transaction_count(actor)
    {:ok, unique_ministries} = Statistics.get_unique_ministries_count(actor)
    {:ok, ministry_summary} = Statistics.get_ministry_funds_by_ministry(actor)
    {:ok, ministry_revenue_chart} = Statistics.get_ministry_revenue_chart_data(actor)

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
    |> assign(:ministry_revenue, ministry_revenue)
    |> assign(:ministry_expenses, ministry_expenses)
    |> assign(:ministry_balance, ministry_balance)
    |> assign(:ministry_transaction_count, ministry_transaction_count)
    |> assign(:unique_ministries, unique_ministries)
    |> assign(:ministry_summary, ministry_summary)
    |> assign(:ministry_revenue_chart_json, Jason.encode!(ministry_revenue_chart))
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
                  Visitors ({@current_month})
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
                Contributions ({@current_month})
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
                Revenue ({@current_month})
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
            <h4 class="text-lg font-medium text-white mb-4">Country Distribution</h4>
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

        <div class="grid grid-cols-1 gap-6">
          <%!-- Contribution Count by Type Chart --%>
          <div class="chart-container">
            <h4 class="text-lg font-medium text-white mb-4">Contributions by Type ({@current_month})</h4>
            <canvas
              id="contribution-type-chart"
              phx-hook="BarChart"
              data-chart-data={@contribution_type_stats_json}
              data-chart-title="Contributions by Type"
              data-chart-horizontal="false"
            >
            </canvas>
          </div>
        </div>
      </div>

      <%!-- Ministry Funds Statistics Section --%>
      <div class="mb-8">
        <h3 class="text-xl font-semibold text-white mb-4 flex items-center">
          <.icon name="hero-building-library" class="mr-2 h-6 w-6 text-primary-500" />
          Ministry Funds Overview
        </h3>

        <%!-- Ministry Funds Summary Cards --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-6">
          <%!-- Total Revenue Card --%>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Total Revenue
                </p>
                <p class="text-3xl font-bold text-green-400 mt-2">
                  ${format_currency(@ministry_revenue)}
                </p>
              </div>
              <div class="p-3 bg-green-500/10 rounded-lg">
                <.icon name="hero-arrow-trending-up" class="h-8 w-8 text-green-400" />
              </div>
            </div>
          </div>

          <%!-- Total Expenses Card --%>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Total Expenses
                </p>
                <p class="text-3xl font-bold text-red-400 mt-2">
                  ${format_currency(@ministry_expenses)}
                </p>
              </div>
              <div class="p-3 bg-red-500/10 rounded-lg">
                <.icon name="hero-arrow-trending-down" class="h-8 w-8 text-red-400" />
              </div>
            </div>
          </div>

          <%!-- Net Balance Card --%>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Net Balance
                </p>
                <p class={[
                  "text-3xl font-bold mt-2",
                  if(Decimal.compare(@ministry_balance, Decimal.new(0)) == :gt, do: "text-green-400", else: "text-red-400")
                ]}>
                  ${format_currency(@ministry_balance)}
                </p>
              </div>
              <div class="p-3 bg-blue-500/10 rounded-lg">
                <.icon name="hero-chart-bar" class="h-8 w-8 text-blue-400" />
              </div>
            </div>
          </div>

          <%!-- Active Ministries Card --%>
          <div class="stat-card">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm font-medium text-gray-400 uppercase tracking-wider">
                  Active Ministries
                </p>
                <p class="text-3xl font-bold text-white mt-2">
                  {@unique_ministries}
                </p>
                <p class="text-xs text-gray-500 mt-1">
                  {@ministry_transaction_count} transactions ({@current_month})
                </p>
              </div>
              <div class="p-3 bg-purple-500/10 rounded-lg">
                <.icon name="hero-building-library" class="h-8 w-8 text-purple-400" />
              </div>
            </div>
          </div>
        </div>

        <%!-- Charts Section --%>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <%!-- Ministry Revenue Chart --%>
          <%= if @ministry_revenue_chart_json != "[]" do %>
            <div class="chart-container">
              <h4 class="text-lg font-medium text-white mb-4">Revenue by Ministry ({@current_month})</h4>
              <canvas
                id="ministry-revenue-chart"
                phx-hook="BarChart"
                data-chart-data={@ministry_revenue_chart_json}
                data-chart-title="Ministry Revenue"
                data-chart-horizontal="true"
              >
              </canvas>
            </div>
          <% end %>

          <%!-- Ministry Funds Summary Table --%>
          <%= if @ministry_summary != [] do %>
            <div class="chart-container">
              <h4 class="text-lg font-medium text-white mb-4">Ministry Financial Summary</h4>
              <div class="overflow-x-auto">
                <table class="w-full text-sm text-left">
                  <thead class="text-xs text-gray-400 uppercase border-b border-gray-700">
                    <tr>
                      <th scope="col" class="px-4 py-3">Ministry</th>
                      <th scope="col" class="px-4 py-3 text-right">Revenue</th>
                      <th scope="col" class="px-4 py-3 text-right">Expenses</th>
                      <th scope="col" class="px-4 py-3 text-right">Balance</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for ministry <- @ministry_summary do %>
                      <tr class="border-b border-gray-700/50 hover:bg-gray-800/30 transition-colors">
                        <td class="px-4 py-3 font-medium text-white">
                          {ministry.label}
                        </td>
                        <td class="px-4 py-3 text-right text-green-400">
                          ${format_number(ministry.revenue)}
                        </td>
                        <td class="px-4 py-3 text-right text-red-400">
                          ${format_number(ministry.expenses)}
                        </td>
                        <td class={[
                          "px-4 py-3 text-right font-semibold",
                          if(ministry.balance >= 0, do: "text-green-400", else: "text-red-400")
                        ]}>
                          ${format_number(ministry.balance)}
                        </td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          <% end %>
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

  defp format_number(number) when is_float(number) do
    number
    |> :erlang.float_to_binary(decimals: 2)
    |> String.split(".")
    |> case do
      [whole, decimal_part] ->
        format_whole_number(whole) <> "." <> decimal_part

      [whole] ->
        format_whole_number(whole) <> ".00"
    end
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> format_whole_number()
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
