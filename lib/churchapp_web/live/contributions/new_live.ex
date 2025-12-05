defmodule ChurchappWeb.ContributionsLive.NewLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Contributions
  alias Chms.Church.ContributionTypes
  alias AshPhoenix.Form

  def mount(_params, _session, socket) do
    # Get the current user for authorization
    actor = socket.assigns[:current_user]

    form =
      Contributions
      |> Form.for_create(:create,
        api: Chms.Church,
        forms: [auto?: true],
        actor: actor
      )
      |> to_form()

    contribution_types = ContributionTypes.all_type_options()

    socket =
      socket
      |> assign(:page_title, "New Contribution")
      |> assign(:form, form)
      |> assign(:contribution_types, contribution_types)
      |> assign(:show_custom_type_modal, false)
      |> assign(:custom_type_input, "")
      |> assign(:custom_type_error, nil)

    {:ok, socket}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("open_custom_type_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_custom_type_modal, true)
     |> assign(:custom_type_input, "")
     |> assign(:custom_type_error, nil)}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :show_custom_type_modal, false)}
  end

  def handle_event("validate_custom_type", %{"custom_type" => value}, socket) do
    {:noreply,
     socket
     |> assign(:custom_type_input, value)
     |> assign(:custom_type_error, nil)}
  end

  def handle_event("save_custom_type", %{"custom_type" => custom_type}, socket) do
    custom_type = String.trim(custom_type)

    if custom_type == "" do
      {:noreply,
       socket
       |> assign(:custom_type_error, "Please enter a contribution type name")}
    else
      # Add the new type to the list and select it in the form
      updated_types = socket.assigns.contribution_types ++ [{custom_type, custom_type}]

      # Update the form with the new custom type
      form =
        socket.assigns.form.source
        |> Form.validate(%{"contribution_type" => custom_type})
        |> to_form()

      {:noreply,
       socket
       |> assign(:contribution_types, updated_types)
       |> assign(:form, form)
       |> assign(:show_custom_type_modal, false)
       |> assign(:custom_type_input, "")
       |> put_flash(:info, "New contribution type '#{custom_type}' added successfully")}
    end
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _contribution} ->
        {:noreply,
         socket
         |> put_flash(:info, "Contribution created successfully")
         |> push_navigate(to: ~p"/contributions")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="mb-6">
        <.link
          navigate={~p"/contributions"}
          class="flex items-center mb-4 text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to List
        </.link>
        <h2 class="text-2xl font-bold text-white">New Contribution</h2>
        <p class="mt-1 text-gray-500">
          Record a new contribution, tithe, offering, or expense.
        </p>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <.form for={@form} phx-change="validate" phx-submit="save" id="contribution-form">
          <div class="p-6 space-y-6">
            <%!-- Contribution Details Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-currency-dollar" class="mr-2 h-5 w-5 text-primary-500" />
                Contribution Details
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <%!-- Congregant Selector --%>
                <div class="sm:col-span-3">
                  <label for="congregant" class="block text-sm font-medium text-gray-400">
                    Congregant <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <.live_component
                      module={ChurchappWeb.CongregantSelector}
                      id="congregant-selector-new"
                      field={@form[:congregant_id]}
                      form={@form}
                      actor={@current_user}
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="contribution-date" class="block text-sm font-medium text-gray-400">
                    Date <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:contribution_date]}
                      type="datetime-local"
                      phx-hook="DatePicker"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-6">
                  <label for="contribution-type" class="block text-sm font-medium text-gray-400">
                    Contribution Type <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1 flex gap-2">
                    <div class="flex-1">
                      <.live_component
                        module={ChurchappWeb.ContributionTypeSelector}
                        id="contribution-type-selector-new"
                        field={@form[:contribution_type]}
                        form={@form}
                        contribution_types={@contribution_types}
                      />
                    </div>
                    <div class="relative group">
                      <button
                        type="button"
                        phx-click="open_custom_type_modal"
                        class="flex items-center h-[42px] px-4 text-sm font-medium text-primary-500 bg-primary-500/10 border border-primary-500/20 rounded-md hover:bg-primary-500/20 hover:border-primary-500/30 transition-all duration-200 whitespace-nowrap"
                      >
                        <.icon name="hero-plus" class="h-5 w-5 mr-1.5" /> Add Custom
                      </button>
                      <%!-- Tooltip --%>
                      <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-1.5 bg-dark-700 text-white text-xs rounded-md shadow-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap">
                        Create a new contribution type
                        <div class="absolute top-full left-1/2 transform -translate-x-1/2 -mt-1 border-4 border-transparent border-t-dark-700">
                        </div>
                      </div>
                    </div>
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
                  <label for="revenue" class="block text-sm font-medium text-gray-400">
                    Amount <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:revenue]}
                      type="number"
                      step="0.01"
                      placeholder="0.00"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
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
                    placeholder="Add any additional notes about this contribution..."
                    class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                  />
                </div>
              </div>
            </div>
          </div>

          <div class="px-6 py-4 flex justify-end space-x-3 bg-dark-700/50 border-t border-dark-700">
            <.link
              navigate={~p"/contributions"}
              class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded-md shadow-sm hover:bg-dark-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-primary-500 border border-transparent rounded-md shadow-sm hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors"
            >
              Save Contribution
            </button>
          </div>
        </.form>
      </div>

      <%!-- Custom Type Modal --%>
      <%= if @show_custom_type_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto animate-fade-in"
          phx-window-keydown="close_modal"
          phx-key="escape"
        >
          <div class="flex min-h-screen items-center justify-center p-4">
            <%!-- Backdrop --%>
            <div
              class="fixed inset-0 modal-backdrop transition-opacity"
              phx-click="close_modal"
            >
            </div>
            <%!-- Modal --%>
            <div class="relative bg-dark-800 rounded-lg shadow-xl border border-dark-700 w-full max-w-md p-6 z-10 animate-scale-in">
              <%!-- Header --%>
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white flex items-center">
                  <.icon name="hero-plus-circle" class="mr-2 h-5 w-5 text-primary-500" />
                  Add Custom Contribution Type
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
                <label for="modal-custom-type" class="block text-sm font-medium text-gray-400 mb-2">
                  Type Name <span class="text-red-500">*</span>
                </label>
                <form phx-change="validate_custom_type">
                  <input
                    type="text"
                    id="modal-custom-type"
                    name="custom_type"
                    value={@custom_type_input}
                    placeholder="e.g., Building Fund, Special Offering..."
                    class={[
                      "block w-full px-3 py-2 text-white bg-dark-900 border rounded-md shadow-sm sm:text-sm focus:ring-2 focus:ring-primary-500 focus:outline-none transition-colors",
                      @custom_type_error && "border-red-500",
                      !@custom_type_error && "border-dark-700"
                    ]}
                    phx-hook="AutoFocus"
                  />
                </form>
                <%= if @custom_type_error do %>
                  <p class="mt-2 text-sm text-red-400">{@custom_type_error}</p>
                <% end %>
                <p class="mt-2 text-xs text-gray-500">
                  This type will be saved and available for all future contributions
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
                  phx-click="save_custom_type"
                  phx-value-custom_type={@custom_type_input}
                  class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-sm transition-colors"
                >
                  <span class="flex items-center">
                    <.icon name="hero-check" class="mr-1 h-4 w-4" /> Save Type
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
