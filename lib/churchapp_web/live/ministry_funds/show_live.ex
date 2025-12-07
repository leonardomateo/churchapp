defmodule ChurchappWeb.MinistryFundsLive.ShowLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns[:current_user]

    case Ash.get(Chms.Church.MinistryFunds, id, actor: actor) do
      {:ok, ministry_fund} ->
        # Get recent transactions for the same ministry
        recent_transactions =
          Chms.Church.MinistryFunds
          |> Ash.Query.filter(ministry_name == ^ministry_fund.ministry_name)
          |> Ash.Query.filter(id != ^ministry_fund.id)
          |> Ash.Query.sort(transaction_date: :desc)
          |> Ash.Query.limit(5)
          |> Ash.read!(actor: actor)

        # Calculate ministry balance
        all_transactions =
          Chms.Church.MinistryFunds
          |> Ash.Query.filter(ministry_name == ^ministry_fund.ministry_name)
          |> Ash.read!(actor: actor)

        balance = calculate_balance(all_transactions)

        socket =
          socket
          |> assign(:page_title, "Transaction Details")
          |> assign(:ministry_fund, ministry_fund)
          |> assign(:recent_transactions, recent_transactions)
          |> assign(:ministry_balance, balance)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Transaction not found")
         |> push_navigate(to: ~p"/ministry-funds")}
    end
  end

  defp calculate_balance(transactions) do
    revenues =
      transactions
      |> Enum.filter(&(&1.transaction_type == :revenue))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    expenses =
      transactions
      |> Enum.filter(&(&1.transaction_type == :expense))
      |> Enum.map(& &1.amount)
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

    Decimal.sub(revenues, expenses)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="mb-6">
        <.link
          navigate={~p"/ministry-funds"}
          class="flex items-center mb-4 text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to List
        </.link>
        <div class="flex items-center justify-between">
          <h2 class="text-2xl font-bold text-white">Transaction Details</h2>
          <div class="flex items-center gap-2">
            <.link
              navigate={~p"/ministry-funds/#{@ministry_fund}/edit"}
              class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
            >
              <.icon name="hero-pencil-square" class="mr-2 h-4 w-4" /> Edit
            </.link>
          </div>
        </div>
      </div>

      <%!-- Ministry Balance Card --%>
      <div class="mb-6 bg-dark-800 rounded-lg p-6 border border-dark-700">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-sm text-gray-400">Ministry Balance</p>
            <p class="text-lg font-medium text-white mt-1">{@ministry_fund.ministry_name}</p>
          </div>
          <div class="text-right">
            <p class="text-sm text-gray-400">Current Balance</p>
            <p class={[
              "text-3xl font-bold mt-1",
              Decimal.positive?(@ministry_balance) && "text-green-400",
              Decimal.negative?(@ministry_balance) && "text-red-400",
              Decimal.equal?(@ministry_balance, Decimal.new(0)) && "text-gray-400"
            ]}>
              ${Decimal.to_string(@ministry_balance, :normal)}
            </p>
          </div>
        </div>
      </div>

      <%!-- Transaction Details Card --%>
      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden mb-6">
        <div class="px-6 py-4 border-b border-dark-700">
          <h3 class="text-lg font-medium text-white flex items-center">
            <.icon name="hero-document-text" class="mr-2 h-5 w-5 text-primary-500" />
            Transaction Information
          </h3>
        </div>
        <div class="p-6 space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%!-- Transaction Type --%>
            <div>
              <label class="block text-sm font-medium text-gray-400 mb-2">
                Transaction Type
              </label>
              <span class={[
                "inline-flex items-center px-3 py-1.5 rounded-full text-sm font-medium border",
                @ministry_fund.transaction_type == :revenue &&
                  "bg-green-500/10 text-green-400 border-green-500/20",
                @ministry_fund.transaction_type == :expense &&
                  "bg-red-500/10 text-red-400 border-red-500/20"
              ]}>
                <%= if @ministry_fund.transaction_type == :revenue do %>
                  <.icon name="hero-arrow-trending-up" class="mr-1.5 h-4 w-4" /> Revenue
                <% else %>
                  <.icon name="hero-arrow-trending-down" class="mr-1.5 h-4 w-4" /> Expense
                <% end %>
              </span>
            </div>

            <%!-- Amount --%>
            <div>
              <label class="block text-sm font-medium text-gray-400 mb-2">Amount</label>
              <p class={[
                "text-2xl font-bold",
                @ministry_fund.transaction_type == :revenue && "text-green-400",
                @ministry_fund.transaction_type == :expense && "text-red-400"
              ]}>
                ${Decimal.to_string(@ministry_fund.amount, :normal)}
              </p>
            </div>

            <%!-- Ministry --%>
            <div>
              <label class="block text-sm font-medium text-gray-400 mb-2">Ministry</label>
              <p class="text-white">{@ministry_fund.ministry_name}</p>
            </div>

            <%!-- Transaction Date --%>
            <div>
              <label class="block text-sm font-medium text-gray-400 mb-2">
                Transaction Date
              </label>
              <p class="text-white">
                {Calendar.strftime(@ministry_fund.transaction_date, "%B %d, %Y at %I:%M %p")}
              </p>
            </div>
          </div>

          <%!-- Notes --%>
          <%= if @ministry_fund.notes do %>
            <div>
              <label class="block text-sm font-medium text-gray-400 mb-2">Notes</label>
              <p class="text-white whitespace-pre-wrap">{@ministry_fund.notes}</p>
            </div>
          <% end %>

          <%!-- Metadata --%>
          <div class="pt-4 border-t border-dark-700">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-sm">
              <div>
                <span class="text-gray-400">Created:</span>
                <span class="text-white ml-2">
                  {Calendar.strftime(@ministry_fund.inserted_at, "%B %d, %Y at %I:%M %p")}
                </span>
              </div>
              <div>
                <span class="text-gray-400">Last Updated:</span>
                <span class="text-white ml-2">
                  {Calendar.strftime(@ministry_fund.updated_at, "%B %d, %Y at %I:%M %p")}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Recent Transactions for Same Ministry --%>
      <%= if @recent_transactions != [] do %>
        <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
          <div class="px-6 py-4 border-b border-dark-700">
            <h3 class="text-lg font-medium text-white flex items-center">
              <.icon name="hero-clock" class="mr-2 h-5 w-5 text-primary-500" />
              Recent Transactions for {@ministry_fund.ministry_name}
            </h3>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full">
              <thead>
                <tr class="border-b border-dark-700">
                  <th
                    scope="col"
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                  >
                    Date
                  </th>
                  <th
                    scope="col"
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                  >
                    Type
                  </th>
                  <th
                    scope="col"
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                  >
                    Amount
                  </th>
                  <th
                    scope="col"
                    class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
                  >
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="bg-dark-800">
                <tr
                  :for={transaction <- @recent_transactions}
                  class="border-b border-dark-700 hover:bg-dark-700/40 transition-colors"
                >
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                    {Calendar.strftime(transaction.transaction_date, "%B %d, %Y")}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap">
                    <span class={[
                      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border",
                      transaction.transaction_type == :revenue &&
                        "bg-green-500/10 text-green-400 border-green-500/20",
                      transaction.transaction_type == :expense &&
                        "bg-red-500/10 text-red-400 border-red-500/20"
                    ]}>
                      {if transaction.transaction_type == :revenue, do: "Revenue", else: "Expense"}
                    </span>
                  </td>
                  <td class={[
                    "px-6 py-4 whitespace-nowrap text-sm font-medium",
                    transaction.transaction_type == :revenue && "text-green-400",
                    transaction.transaction_type == :expense && "text-red-400"
                  ]}>
                    ${Decimal.to_string(transaction.amount, :normal)}
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-right text-sm">
                    <.link
                      navigate={~p"/ministry-funds/#{transaction}"}
                      class="text-primary-500 hover:text-primary-400 transition-colors"
                    >
                      View
                    </.link>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
