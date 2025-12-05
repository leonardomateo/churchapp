defmodule ChurchappWeb.MinistryFundsLive.NewLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.MinistryFunds
  alias Chms.Church.Ministries
  alias AshPhoenix.Form

  def mount(_params, _session, socket) do
    # Get the current user for authorization
    actor = socket.assigns[:current_user]

    form =
      MinistryFunds
      |> Form.for_create(:create,
        api: Chms.Church,
        forms: [auto?: true],
        actor: actor
      )
      |> to_form()

    ministries = Ministries.ministry_options()

    socket =
      socket
      |> assign(:page_title, "New Ministry Fund Transaction")
      |> assign(:form, form)
      |> assign(:ministries, ministries)
      |> assign(:transaction_type, :revenue)
      |> assign(:show_custom_ministry_modal, false)
      |> assign(:custom_ministry_input, "")
      |> assign(:custom_ministry_error, nil)

    {:ok, socket}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("set_transaction_type", %{"type" => type}, socket) do
    type_atom = String.to_existing_atom(type)

    form =
      socket.assigns.form.source
      |> Form.validate(%{"transaction_type" => type_atom})
      |> to_form()

    {:noreply,
     socket
     |> assign(:transaction_type, type_atom)
     |> assign(:form, form)}
  end

  def handle_event("open_custom_ministry_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_custom_ministry_modal, true)
     |> assign(:custom_ministry_input, "")
     |> assign(:custom_ministry_error, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_custom_ministry_modal, false)}
  end

  def handle_event("validate_custom_ministry", %{"custom_ministry" => value}, socket) do
    {:noreply,
     socket
     |> assign(:custom_ministry_input, value)
     |> assign(:custom_ministry_error, nil)}
  end

  def handle_event("save_custom_ministry", %{"custom_ministry" => custom_ministry}, socket) do
    custom_ministry = String.trim(custom_ministry)

    if custom_ministry == "" do
      {:noreply,
       socket
       |> assign(:custom_ministry_error, "Please enter a ministry name")}
    else
      # Add the new ministry to the list and select it in the form
      updated_ministries = socket.assigns.ministries ++ [{custom_ministry, custom_ministry}]

      # Update the form with the new custom ministry
      form =
        socket.assigns.form.source
        |> Form.validate(%{"ministry_name" => custom_ministry})
        |> to_form()

      {:noreply,
       socket
       |> assign(:ministries, updated_ministries)
       |> assign(:form, form)
       |> assign(:show_custom_ministry_modal, false)
       |> assign(:custom_ministry_input, "")
       |> put_flash(:info, "New ministry '#{custom_ministry}' added successfully")}
    end
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Merge the transaction_type from socket assigns into params
    params_with_type = Map.put(params, "transaction_type", socket.assigns.transaction_type)

    case Form.submit(socket.assigns.form, params: params_with_type) do
      {:ok, _ministry_fund} ->
        {:noreply,
         socket
         |> put_flash(:info, "Ministry fund transaction created successfully")
         |> push_navigate(to: ~p"/ministry-funds")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
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
        <h2 class="text-2xl font-bold text-white">New Ministry Fund Transaction</h2>
        <p class="mt-1 text-gray-500">
          Record a revenue or expense transaction for a ministry.
        </p>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <.form for={@form} phx-change="validate" phx-submit="save" id="ministry-fund-form">
          <div class="p-6 space-y-6">
            <%!-- Transaction Type Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-arrows-right-left" class="mr-2 h-5 w-5 text-primary-500" />
                Transaction Type
              </h3>
              <div class="grid grid-cols-2 gap-4">
                <label class={[
                  "flex items-center justify-center px-4 py-3 rounded-lg border-2 cursor-pointer transition-all",
                  @transaction_type == :revenue && "border-green-500 bg-green-500/10",
                  @transaction_type != :revenue && "border-dark-700 hover:border-dark-600"
                ]}>
                  <input
                    type="radio"
                    name="transaction_type"
                    value="revenue"
                    checked={@transaction_type == :revenue}
                    phx-click="set_transaction_type"
                    phx-value-type="revenue"
                    class="sr-only"
                  />
                  <.icon name="hero-arrow-trending-up" class="mr-2 h-5 w-5 text-green-400" />
                  <span class="font-medium text-white">Revenue</span>
                </label>

                <label class={[
                  "flex items-center justify-center px-4 py-3 rounded-lg border-2 cursor-pointer transition-all",
                  @transaction_type == :expense && "border-red-500 bg-red-500/10",
                  @transaction_type != :expense && "border-dark-700 hover:border-dark-600"
                ]}>
                  <input
                    type="radio"
                    name="transaction_type"
                    value="expense"
                    checked={@transaction_type == :expense}
                    phx-click="set_transaction_type"
                    phx-value-type="expense"
                    class="sr-only"
                  />
                  <.icon name="hero-arrow-trending-down" class="mr-2 h-5 w-5 text-red-400" />
                  <span class="font-medium text-white">Expense</span>
                </label>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Ministry Details Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-user-group" class="mr-2 h-5 w-5 text-primary-500" />
                Ministry Details
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <%!-- Ministry Selector --%>
                <div class="sm:col-span-6">
                  <label for="ministry" class="block text-sm font-medium text-gray-400">
                    Ministry <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1 flex gap-2">
                    <div class="flex-1">
                      <.live_component
                        module={ChurchappWeb.MinistrySelector}
                        id="ministry-selector-new"
                        field={@form[:ministry_name]}
                        form={@form}
                        ministries={@ministries}
                      />
                    </div>
                    <div class="relative group">
                      <button
                        type="button"
                        phx-click="open_custom_ministry_modal"
                        class="flex items-center h-[42px] px-4 text-sm font-medium text-primary-500 bg-primary-500/10 border border-primary-500/20 rounded-md hover:bg-primary-500/20 hover:border-primary-500/30 transition-all duration-200 whitespace-nowrap"
                      >
                        <.icon name="hero-plus" class="h-5 w-5 mr-1.5" /> Add Custom
                      </button>
                      <%!-- Tooltip --%>
                      <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-1.5 bg-dark-700 text-white text-xs rounded-md shadow-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap">
                        Create a new ministry
                        <div class="absolute top-full left-1/2 transform -translate-x-1/2 -mt-1 border-4 border-transparent border-t-dark-700">
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="transaction-date" class="block text-sm font-medium text-gray-400">
                    Transaction Date <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:transaction_date]}
                      type="datetime-local"
                      phx-hook="DatePicker"
                      max={DateTime.utc_now() |> DateTime.to_naive() |> NaiveDateTime.to_iso8601() |> String.slice(0, 16)}
                      class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Amount Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-banknotes" class="mr-2 h-5 w-5 text-primary-500" /> Amount
              </h3>

              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-3">
                  <label for="amount" class="block text-sm font-medium text-gray-400">
                    Amount <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:amount]}
                      type="number"
                      step="0.01"
                      placeholder="0.00"
                      class={[
                        "block w-full px-3 py-2 text-white bg-dark-900 border rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500",
                        @transaction_type == :revenue && "border-green-500",
                        @transaction_type == :expense && "border-red-500"
                      ]}
                    />
                  </div>
                  <p class="mt-1 text-xs text-gray-500">
                    <%= if @transaction_type == :revenue do %>
                      Enter the revenue amount received
                    <% else %>
                      Enter the expense amount paid
                    <% end %>
                  </p>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Notes Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-document-text" class="mr-2 h-5 w-5 text-primary-500" /> Notes
              </h3>
              <div>
                <label for="notes" class="block text-sm font-medium text-gray-400">
                  Additional Notes
                </label>
                <div class="mt-1">
                  <.input
                    field={@form[:notes]}
                    type="textarea"
                    rows="4"
                    placeholder="Add any additional notes about this transaction..."
                    class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                  />
                </div>
              </div>
            </div>
          </div>

          <div class="px-6 py-4 flex justify-end space-x-3 bg-dark-700/50 border-t border-dark-700">
            <.link
              navigate={~p"/ministry-funds"}
              class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded-md shadow-sm hover:bg-dark-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-primary-500 border border-transparent rounded-md shadow-sm hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors"
            >
              Save Transaction
            </button>
          </div>
        </.form>
      </div>

      <%!-- Custom Ministry Modal --%>
      <%= if @show_custom_ministry_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto animate-fade-in"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <div class="flex min-h-screen items-center justify-center p-4">
            <%!-- Backdrop --%>
            <div class="fixed inset-0 modal-backdrop transition-opacity" phx-click="close_modal">
            </div>
            <%!-- Modal --%>
            <div class="relative bg-dark-800 rounded-lg shadow-xl border border-dark-700 w-full max-w-md p-6 z-10 animate-scale-in">
              <%!-- Header --%>
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white flex items-center">
                  <.icon name="hero-plus-circle" class="mr-2 h-5 w-5 text-primary-500" />
                  Add Custom Ministry
                </h3>
                <button
                  type="button"
                  phx-click="close_modal"
                  class="text-gray-400 hover:text-white transition-colors"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>
              <%!-- Content --%>
              <div class="mb-6">
                <label for="modal-custom-ministry" class="block text-sm font-medium text-gray-400 mb-2">
                  Ministry Name <span class="text-red-500">*</span>
                </label>
                <form phx-change="validate_custom_ministry">
                  <input
                    type="text"
                    id="modal-custom-ministry"
                    name="custom_ministry"
                    value={@custom_ministry_input}
                    placeholder="e.g., Building Fund, Youth Ministry..."
                    class={[
                      "block w-full px-3 py-2 text-white bg-dark-900 border rounded-md shadow-sm sm:text-sm focus:ring-2 focus:ring-primary-500 focus:outline-none transition-colors",
                      @custom_ministry_error && "border-red-500",
                      !@custom_ministry_error && "border-dark-700"
                    ]}
                    phx-hook="AutoFocus"
                  />
                </form>
                <%= if @custom_ministry_error do %>
                  <p class="mt-2 text-sm text-red-400">{@custom_ministry_error}</p>
                <% end %>
                <p class="mt-2 text-xs text-gray-500">
                  This ministry will be saved and available for all future transactions
                </p>
              </div>
              <%!-- Actions --%>
              <div class="flex justify-end space-x-3">
                <button
                  type="button"
                  phx-click="close_modal"
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  phx-click="save_custom_ministry"
                  phx-value-custom_ministry={@custom_ministry_input}
                  class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-sm transition-colors"
                >
                  <span class="flex items-center">
                    <.icon name="hero-check" class="mr-1 h-4 w-4" /> Save Ministry
                  </span>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
