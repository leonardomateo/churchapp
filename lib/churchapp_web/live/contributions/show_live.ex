defmodule ChurchappWeb.ContributionsLive.ShowLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(%{"id" => id}, _session, socket) do
    # Get the current user for authorization
    actor = socket.assigns[:current_user]

    contribution = Ash.get!(Chms.Church.Contributions, id, load: [:congregant], actor: actor)

    # Get the congregant ID for filtering
    congregant_id = contribution.congregant_id

    # Fetch all contributions from the same congregant
    all_contributions_from_congregant =
      Chms.Church.Contributions
      |> Ash.Query.filter(congregant_id == ^congregant_id)
      |> Ash.Query.sort(contribution_date: :desc)
      |> Ash.read!(actor: actor)

    # Calculate summary statistics
    total_amount =
      all_contributions_from_congregant
      |> Enum.reduce(Decimal.new(0), fn c, acc -> Decimal.add(acc, c.revenue) end)

    total_count = length(all_contributions_from_congregant)

    # Get recent contributions (excluding current one, limit to 10)
    related_contributions =
      all_contributions_from_congregant
      |> Enum.reject(fn c -> c.id == contribution.id end)
      |> Enum.take(10)

    # Set current month/year for monthly stats
    today = Date.utc_today()
    selected_month = today.month
    selected_year = today.year

    # Calculate monthly stats
    {monthly_total, monthly_count} =
      calculate_monthly_stats(all_contributions_from_congregant, selected_month, selected_year)

    {:ok,
     socket
     |> assign(:page_title, "View Contribution")
     |> assign(:contribution, contribution)
     |> assign(:related_contributions, related_contributions)
     |> assign(:all_contributions, all_contributions_from_congregant)
     |> assign(:total_amount, total_amount)
     |> assign(:total_count, total_count)
     |> assign(:selected_month, selected_month)
     |> assign(:selected_year, selected_year)
     |> assign(:monthly_total, monthly_total)
     |> assign(:monthly_count, monthly_count)}
  rescue
    _ ->
      {:ok,
       socket
       |> put_flash(:error, "Contribution not found")
       |> push_navigate(to: ~p"/contributions")}
  end

  def handle_event("change_month_only", %{"month" => month}, socket) do
    selected_month = String.to_integer(month)

    {monthly_total, monthly_count} =
      calculate_monthly_stats(
        socket.assigns.all_contributions,
        selected_month,
        socket.assigns.selected_year
      )

    {:noreply,
     socket
     |> assign(:selected_month, selected_month)
     |> assign(:monthly_total, monthly_total)
     |> assign(:monthly_count, monthly_count)}
  end

  def handle_event("change_year_only", %{"year" => year}, socket) do
    case Integer.parse(year) do
      {selected_year, _} when selected_year >= 2000 and selected_year <= 2099 ->
        {monthly_total, monthly_count} =
          calculate_monthly_stats(
            socket.assigns.all_contributions,
            socket.assigns.selected_month,
            selected_year
          )

        {:noreply,
         socket
         |> assign(:selected_year, selected_year)
         |> assign(:monthly_total, monthly_total)
         |> assign(:monthly_count, monthly_count)}

      _ ->
        # Invalid year, keep current state
        {:noreply, socket}
    end
  end

  defp calculate_monthly_stats(contributions, month, year) do
    monthly_contributions =
      contributions
      |> Enum.filter(fn c ->
        # Handle DateTime by checking month and year
        date = DateTime.to_date(c.contribution_date)
        date.month == month and date.year == year
      end)

    total =
      Enum.reduce(monthly_contributions, Decimal.new(0), fn c, acc ->
        Decimal.add(acc, c.revenue)
      end)

    count = length(monthly_contributions)

    {total, count}
  end

  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <%!-- Back Navigation and Edit Button --%>
      <div class="mb-6 flex items-center justify-between">
        <.link
          navigate={~p"/contributions"}
          class="flex items-center text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to List
        </.link>

        <.link
          navigate={~p"/contributions/#{@contribution}/edit"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-pencil-square" class="mr-2 w-4 h-4" /> Edit Contribution
        </.link>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <%!-- Contribution Header --%>
        <div class="px-6 py-8 border-b border-dark-700">
          <div class="flex items-center gap-6">
            <div class="flex-shrink-0 w-20 h-20 rounded-full bg-primary-500/10 border-2 border-primary-500/20 flex items-center justify-center">
              <.icon name="hero-banknotes" class="h-10 w-10 text-primary-500" />
            </div>

            <div class="flex-1">
              <div class="flex items-center gap-3 mb-3">
                <h1 class="text-2xl font-bold text-white">
                  {@contribution.contribution_type}
                </h1>
                <span class="px-3 py-1 inline-flex text-xs font-medium rounded-full bg-green-900/60 text-green-400 border border-green-800">
                  ${Decimal.to_string(@contribution.revenue, :normal)}
                </span>
              </div>

              <div class="flex flex-wrap items-center gap-4 text-sm text-gray-400">
                <span class="flex items-center gap-1.5">
                  <.icon name="hero-calendar" class="h-4 w-4" />
                  <span
                    id="contribution-date-header"
                    phx-hook="LocalTime"
                    data-utc={DateTime.to_iso8601(@contribution.contribution_date)}
                    data-format="datetime"
                  >
                    {Calendar.strftime(@contribution.contribution_date, "%B %d, %Y at %I:%M %p")}
                  </span>
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Contribution Details --%>
        <div class="p-8">
          <%!-- Congregant Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-user-circle" class="mr-2 h-5 w-5 text-primary-500" />
              Contributor Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <.link
                    navigate={~p"/congregants/#{@contribution.congregant}"}
                    class="text-primary-500 hover:text-primary-400 transition-colors"
                  >
                    {@contribution.congregant.first_name} {@contribution.congregant.last_name}
                  </.link>
                </dd>
              </div>

              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Member ID
                </dt>
                <dd class="mt-2 text-sm text-white">
                  #{@contribution.congregant.member_id}
                </dd>
              </div>
            </dl>
          </div>

          <hr class="border-dark-700" />

          <%!-- Contribution Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-document-text" class="mr-2 h-5 w-5 text-primary-500" />
              Contribution Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-500/10 text-primary-500 border border-primary-500/20">
                    {@contribution.contribution_type}
                  </span>
                </dd>
              </div>

              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </dt>
                <dd class="mt-2 text-sm font-medium text-green-400">
                  ${Decimal.to_string(@contribution.revenue, :normal)}
                </dd>
              </div>

              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date & Time
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <span
                    id="contribution-date-detail"
                    phx-hook="LocalTime"
                    data-utc={DateTime.to_iso8601(@contribution.contribution_date)}
                    data-format="datetime"
                  >
                    {Calendar.strftime(@contribution.contribution_date, "%B %d, %Y at %I:%M %p")}
                  </span>
                </dd>
              </div>
            </dl>
          </div>

          <%= if @contribution.notes do %>
            <hr class="border-dark-700" />

            <%!-- Notes Section --%>
            <div class="py-8">
              <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-pencil" class="mr-2 h-5 w-5 text-primary-500" /> Notes
              </h3>
              <div class="ml-6">
                <dd class="text-sm text-white leading-relaxed whitespace-pre-wrap">
                  {@contribution.notes}
                </dd>
              </div>
            </div>
          <% end %>

          <hr class="border-dark-700" />

          <%!-- System Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-clock" class="mr-2 h-5 w-5 text-primary-500" /> Record Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Record Created
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <span
                    id="contribution-created-at"
                    phx-hook="LocalTime"
                    data-utc={DateTime.to_iso8601(@contribution.inserted_at)}
                    data-format="datetime"
                  >
                    {Calendar.strftime(@contribution.inserted_at, "%B %d, %Y at %I:%M %p")}
                  </span>
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Record Last Updated
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <span
                    id="contribution-updated-at"
                    phx-hook="LocalTime"
                    data-utc={DateTime.to_iso8601(@contribution.updated_at)}
                    data-format="datetime"
                  >
                    {Calendar.strftime(@contribution.updated_at, "%B %d, %Y at %I:%M %p")}
                  </span>
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>

      <%!-- Other Contributions by this Contributor --%>
      <%= if @total_count > 1 do %>
        <div class="mt-8 bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
          <div class="px-6 py-6 border-b border-dark-700">
            <div class="flex items-center justify-between">
              <div>
                <h3 class="text-lg font-medium text-white flex items-center">
                  <.icon name="hero-banknotes" class="mr-2 h-5 w-5 text-primary-500" />
                  Other Contributions by {@contribution.congregant.first_name} {@contribution.congregant.last_name}
                </h3>
                <p class="mt-1 text-sm text-gray-400">
                  Contribution history and giving patterns
                </p>
              </div>
              <.link
                navigate={~p"/congregants/#{@contribution.congregant}"}
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-primary-500 bg-primary-500/10 hover:bg-primary-500/20 rounded-md border border-primary-500/20 transition-colors"
              >
                <.icon name="hero-user-circle" class="mr-2 h-4 w-4" /> View Member Profile
              </.link>
            </div>

            <%!-- Month/Year Selectors --%>
            <div class="mt-6 mb-4">
              <div class="flex gap-3">
                <div class="flex-1">
                  <label class="block text-xs font-medium text-gray-400 mb-2 uppercase tracking-wider">
                    Select Month
                  </label>
                  <form id="month-form" phx-change="change_month_only">
                    <select
                      name="month"
                      class="h-[42px] w-full px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
                    >
                      <option value="1" selected={@selected_month == 1}>January</option>
                      <option value="2" selected={@selected_month == 2}>February</option>
                      <option value="3" selected={@selected_month == 3}>March</option>
                      <option value="4" selected={@selected_month == 4}>April</option>
                      <option value="5" selected={@selected_month == 5}>May</option>
                      <option value="6" selected={@selected_month == 6}>June</option>
                      <option value="7" selected={@selected_month == 7}>July</option>
                      <option value="8" selected={@selected_month == 8}>August</option>
                      <option value="9" selected={@selected_month == 9}>September</option>
                      <option value="10" selected={@selected_month == 10}>October</option>
                      <option value="11" selected={@selected_month == 11}>November</option>
                      <option value="12" selected={@selected_month == 12}>December</option>
                    </select>
                  </form>
                </div>

                <div class="flex-1">
                  <label class="block text-xs font-medium text-gray-400 mb-2 uppercase tracking-wider">
                    Select Year
                  </label>
                  <form id="year-form" phx-change="change_year_only">
                    <input
                      type="number"
                      name="year"
                      value={@selected_year}
                      min="2000"
                      max="2099"
                      placeholder="Enter year"
                      phx-debounce="800"
                      class="h-[42px] w-full px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors"
                    />
                  </form>
                </div>
              </div>
            </div>

            <%!-- Summary Statistics --%>
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div class="bg-dark-900/50 rounded-lg px-4 py-3 border border-dark-700">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {month_name(@selected_month)} Contributions
                </dt>
                <dd class="mt-2 text-2xl font-bold text-white">
                  {@monthly_count}
                </dd>
              </div>

              <div class="bg-dark-900/50 rounded-lg px-4 py-3 border border-dark-700">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  {month_name(@selected_month)} {@selected_year}
                </dt>
                <dd class="mt-2 text-2xl font-bold text-primary-500">
                  ${Decimal.to_string(@monthly_total, :normal)}
                </dd>
              </div>

              <div class="bg-dark-900/50 rounded-lg px-4 py-3 border border-dark-700">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Total Amount
                </dt>
                <dd class="mt-2 text-2xl font-bold text-green-400">
                  ${Decimal.to_string(@total_amount, :normal)}
                </dd>
              </div>
            </div>
          </div>

          <%!-- Recent Contributions Table --%>
          <%= if @related_contributions != [] do %>
            <div class="overflow-x-auto">
              <table class="min-w-full divide-y divide-dark-700">
                <thead class="bg-dark-700/50">
                  <tr>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Date
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Type
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Amount
                    </th>
                    <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Notes
                    </th>
                    <th class="px-6 py-3 text-right text-xs font-medium text-gray-400 uppercase tracking-wider">
                      Actions
                    </th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-dark-700">
                  <tr
                    :for={related_contribution <- @related_contributions}
                    class="hover:bg-dark-700/30 transition-colors"
                  >
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                      <span
                        id={"related-contrib-date-#{related_contribution.id}"}
                        phx-hook="LocalTime"
                        data-utc={DateTime.to_iso8601(related_contribution.contribution_date)}
                        data-format="datetime"
                      >
                        {Calendar.strftime(
                          related_contribution.contribution_date,
                          "%b %d, %Y at %I:%M %p"
                        )}
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-500/10 text-primary-500 border border-primary-500/20">
                        {related_contribution.contribution_type}
                      </span>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-green-400">
                      ${Decimal.to_string(related_contribution.revenue, :normal)}
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-400 max-w-xs truncate">
                      {related_contribution.notes || "—"}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <.link
                        navigate={~p"/contributions/#{related_contribution}"}
                        class="text-primary-500 hover:text-primary-400 transition-colors"
                      >
                        View
                      </.link>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <%!-- View All Link --%>
            <%= if @total_count > 11 do %>
              <div class="px-6 py-4 bg-dark-700/30 border-t border-dark-700 text-center">
                <.link
                  navigate={~p"/congregants/#{@contribution.congregant}"}
                  class="inline-flex items-center text-sm font-medium text-primary-500 hover:text-primary-400 transition-colors"
                >
                  View All {@total_count} Contributions
                  <.icon name="hero-arrow-right" class="ml-2 h-4 w-4" />
                </.link>
              </div>
            <% end %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
