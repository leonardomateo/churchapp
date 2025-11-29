defmodule ChurchappWeb.CongregantsLive.EditLive do
  use ChurchappWeb, :live_view

  alias AshPhoenix.Form

  def mount(%{"id" => id}, _session, socket) do
    case Chms.Church.get_congregant_by_id(id) do
      {:ok, congregant} ->
        form =
          congregant
          |> Form.for_update(:update, api: Chms.Church)
          |> to_form()

        socket =
          socket
          |> assign(:page_title, "Edit Congregant")
          |> assign(:congregant, congregant)
          |> assign(:form, form)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Congregant not found")
         |> push_navigate(to: ~p"/congregants")}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, congregant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Congregant updated successfully")
         |> push_navigate(to: ~p"/congregants/#{congregant}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="mb-6">
        <.link
          navigate={~p"/congregants/#{@congregant}"}
          class="flex items-center mb-4 text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" />
          Back to Details
        </.link>
        <h2 class="text-2xl font-bold text-white">Edit Member</h2>
        <p class="mt-1 text-gray-500">
          Update details for {@congregant.first_name} {@congregant.last_name}
        </p>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <.form for={@form} phx-change="validate" phx-submit="save">
          <div class="p-6 space-y-6">
            <%!-- Personal Information Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-user" class="mr-2 h-5 w-5 text-primary-500" />
                Personal Information
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-2">
                  <label for="first-name" class="block text-sm font-medium text-gray-400">
                    First name
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:first_name]}
                      type="text"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="last-name" class="block text-sm font-medium text-gray-400">
                    Last name
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:last_name]}
                      type="text"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="member-id" class="block text-sm font-medium text-gray-400">
                    Member ID
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:member_id]}
                      type="text"
                      readonly
                      class="block w-full px-3 py-2 text-gray-400 bg-dark-900 border border-dark-700 rounded-md shadow-sm cursor-not-allowed sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="dob" class="block text-sm font-medium text-gray-400">
                    Date of Birth
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:dob]}
                      type="date"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="member-since" class="block text-sm font-medium text-gray-400">
                    Member Since
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:member_since]}
                      type="date"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Contact Information Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-phone" class="mr-2 h-5 w-5 text-primary-500" />
                Contact Information
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-2">
                  <label for="mobile-tel" class="block text-sm font-medium text-gray-400">
                    Mobile Phone
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:mobile_tel]}
                      type="tel"
                      phx-hook="PhoneFormat"
                      placeholder="(123) 456 - 7890"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="home-tel" class="block text-sm font-medium text-gray-400">
                    Home Phone
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:home_tel]}
                      type="tel"
                      phx-hook="PhoneFormat"
                      placeholder="(123) 456 - 7890"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="work-tel" class="block text-sm font-medium text-gray-400">
                    Work Phone
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:work_tel]}
                      type="tel"
                      phx-hook="PhoneFormat"
                      placeholder="(123) 456 - 7890"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Address Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-map-pin" class="mr-2 h-5 w-5 text-primary-500" />
                Address
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-6">
                  <label for="address" class="block text-sm font-medium text-gray-400">
                    Street Address
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:address]}
                      type="text"
                      placeholder="123 Main Street"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="suite" class="block text-sm font-medium text-gray-400">
                    Suite/Apt
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:suite]}
                      type="text"
                      placeholder="Apt 4B"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="city" class="block text-sm font-medium text-gray-400">
                    City
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:city]}
                      type="text"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="state" class="block text-sm font-medium text-gray-400">
                    State
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:state]}
                      type="text"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="zip-code" class="block text-sm font-medium text-gray-400">
                    Zip Code
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:zip_code]}
                      type="text"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="country" class="block text-sm font-medium text-gray-400">
                    Country
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:country]}
                      type="text"
                      placeholder="USA"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Church Details Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-building-library" class="mr-2 h-5 w-5 text-primary-500" />
                Church Details
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-3">
                  <label for="status" class="block text-sm font-medium text-gray-400">
                    Membership Status
                  </label>
                  <div class="mt-1">
                    <.input
                      field={@form[:status]}
                      type="select"
                      options={[
                        {"Active Member", :member},
                        {"Visitor", :visitor},
                        {"Honorific", :honorific},
                        {"Deceased", :deceased}
                      ]}
                      class="block w-full px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="is-leader" class="block text-sm font-medium text-gray-400">
                    Role
                  </label>
                  <div class="mt-1 flex items-center h-10">
                    <label class="inline-flex items-center cursor-pointer">
                      <.input
                        field={@form[:is_leader]}
                        type="checkbox"
                        class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded form-checkbox focus:ring-primary-500"
                      />
                      <span class="ml-2 text-sm text-gray-300">Is a Leader</span>
                    </label>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="px-6 py-4 flex justify-end space-x-3 bg-dark-700/50 border-t border-dark-700">
            <.link
              navigate={~p"/congregants/#{@congregant}"}
              class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded-md shadow-sm hover:bg-dark-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors"
            >
              Cancel
            </.link>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-primary-500 border border-transparent rounded-md shadow-sm hover:bg-primary-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500 transition-colors"
            >
              Save Changes
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
