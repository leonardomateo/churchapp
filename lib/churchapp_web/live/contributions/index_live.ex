defmodule ChurchappWeb.ContributionsLive.IndexLive do
  use ChurchappWeb, :live_view

  def mount(_params, _session, socket) do
    contributions =
      Chms.Church.Contributions
      |> Ash.Query.load([:congregant])
      |> Ash.Query.sort(contribution_date: :desc)
      |> Ash.read!()

    {:ok,
     socket
     |> assign(:page_title, "Contributions")
     |> stream(:contributions, contributions)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    contribution = Ash.get!(Chms.Church.Contributions, id)

    case Ash.destroy(contribution) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Contribution deleted successfully")
         |> stream_delete(:contributions, contribution)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to delete contribution")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <div class="mb-6 flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-white">Contributions</h2>
          <p class="mt-1 text-gray-400">
            Manage church contributions, tithes, offerings, and expenses.
          </p>
        </div>
        <.link
          navigate={~p"/contributions/new"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-plus" class="mr-2 w-5 h-5" /> New Contribution
        </.link>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-dark-700">
            <thead class="bg-dark-700/50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider">
                  Congregant
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
            <tbody id="contributions" phx-update="stream" class="divide-y divide-dark-700">
              <tr
                :for={{id, contribution} <- @streams.contributions}
                id={id}
                class="hover:bg-dark-700/30 transition-colors"
              >
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                  {Calendar.strftime(contribution.contribution_date, "%b %d, %Y")}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-white">
                  {contribution.congregant.first_name} {contribution.congregant.last_name}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-500/10 text-primary-500 border border-primary-500/20">
                    {contribution.contribution_type}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-green-400">
                  ${Decimal.to_string(contribution.revenue, :normal)}
                </td>
                <td class="px-6 py-4 text-sm text-gray-400 max-w-xs truncate">
                  {contribution.notes || "-"}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <.link
                    navigate={~p"/contributions/#{contribution}/edit"}
                    class="text-primary-500 hover:text-primary-600 mr-4"
                  >
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={contribution.id}
                    data-confirm="Are you sure you want to delete this contribution?"
                    class="text-red-500 hover:text-red-600"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
