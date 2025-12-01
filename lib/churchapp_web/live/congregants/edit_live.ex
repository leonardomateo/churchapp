defmodule ChurchappWeb.CongregantsLive.EditLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Ministries
  alias AshPhoenix.Form

  def mount(%{"id" => id}, _session, socket) do
    case Chms.Church.get_congregant_by_id(id) do
      {:ok, congregant} ->
        # Convert ministries array to comma-separated string for form display
        ministries_string =
          if congregant.ministries && congregant.ministries != [] do
            Enum.join(congregant.ministries, ", ")
          else
            ""
          end

        form =
          congregant
          |> Form.for_update(:update, api: Chms.Church)
          |> Form.validate(%{"ministries_string" => ministries_string})
          |> to_form()

        socket =
          socket
          |> assign(:page_title, "Edit Congregant")
          |> assign(:congregant, congregant)
          |> assign(:form, form)
          |> assign(:uploaded_files, [])
          |> assign(:ministries_options, Ministries.ministry_options())
          |> assign(:selected_ministries, congregant.ministries || [])
          |> allow_upload(:image,
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_file_size: 5_000_000,
            max_entries: 1,
            auto_upload: false
          )

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Congregant not found")
         |> push_navigate(to: ~p"/congregants")}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    # Handle ministries array from checkboxes
    {ministries_string, selected_ministries} =
      case params["ministries"] do
        ministries when is_list(ministries) ->
          # Filter out empty strings from hidden input
          filtered = Enum.reject(ministries, &(&1 == ""))
          {Enum.join(filtered, ","), filtered}

        ministries when is_binary(ministries) and ministries != "" ->
          {ministries, [ministries]}

        _ ->
          {"", []}
      end

    params = Map.put(params, "ministries_string", ministries_string)

    form = Form.validate(socket.assigns.form, params)
    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:selected_ministries, selected_ministries)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    # Handle ministries array from checkboxes
    {ministries_string, filtered_ministries} =
      case params["ministries"] do
        ministries when is_list(ministries) ->
          # Filter out empty strings from hidden input
          filtered = Enum.reject(ministries, &(&1 == ""))
          {Enum.join(filtered, ","), filtered}

        ministries when is_binary(ministries) and ministries != "" ->
          # Sometimes Phoenix sends a single value as string
          {ministries, [ministries]}

        _ ->
          {"", []}
      end

    params =
      params
      |> Map.put("ministries_string", ministries_string)
      |> Map.put("ministries", filtered_ministries)

    # Check if there are any uploaded files
    case socket.assigns.uploads.image.entries do
      [] ->
        # No image uploaded, proceed without image
        case Form.submit(socket.assigns.form, params: params) do
          {:ok, congregant} ->
            {:noreply,
             socket
             |> put_flash(:info, "Congregant updated successfully")
             |> push_navigate(to: ~p"/congregants/#{congregant}")}

          {:error, form} ->
            {:noreply,
             socket
             |> assign(:form, form)
             |> put_flash(:error, "Please check the form for errors")}
        end

      _ ->
        # There are uploaded files, consume them
        uploaded_files =
          consume_uploaded_entries(socket, :image, fn %{path: temp_path}, entry ->
            # Generate unique filename
            extension = Path.extname(entry.client_name)
            filename = "#{System.unique_integer([:positive])}#{extension}"
            dest_path = Path.join(["priv/static/uploads/congregants", filename])

            # Ensure directory exists
            File.mkdir_p!(Path.dirname(dest_path))

            # Copy file to destination
            File.cp!(temp_path, dest_path)

            # Return the relative path for storage wrapped in :ok tuple
            {:ok, "/uploads/congregants/#{filename}"}
          end)

        # Add image path to params if an image was uploaded
        params =
          case uploaded_files do
            [image_path | _] -> Map.put(params, "image", image_path)
            [] -> params
          end

        case Form.submit(socket.assigns.form, params: params) do
          {:ok, congregant} ->
            {:noreply,
             socket
             |> put_flash(:info, "Congregant updated successfully")
             |> push_navigate(to: ~p"/congregants/#{congregant}")}

          {:error, form} ->
            {:noreply,
             socket
             |> assign(:form, form)
             |> put_flash(:error, "Please check the form for errors")}
        end
    end
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("remove-image", _params, socket) do
    # Get current ministries value to preserve it
    ministries_string =
      if socket.assigns.congregant.ministries && socket.assigns.congregant.ministries != [] do
        Enum.join(socket.assigns.congregant.ministries, ", ")
      else
        ""
      end

    # Update the congregant to remove the image
    case Form.submit(socket.assigns.form, params: %{"image" => nil}) do
      {:ok, congregant} ->
        # Rebuild the form with the updated congregant
        form =
          congregant
          |> Form.for_update(:update, api: Chms.Church)
          |> Form.validate(%{"ministries_string" => ministries_string})
          |> to_form()

        {:noreply,
         socket
         |> assign(:congregant, congregant)
         |> assign(:form, form)
         |> put_flash(:info, "Profile image removed")}

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
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Details
        </.link>
        <h2 class="text-2xl font-bold text-white">Edit Congregant</h2>
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
                <.icon name="hero-user" class="mr-2 h-5 w-5 text-primary-500" /> Personal Information
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-2">
                  <label for="first-name" class="block text-sm font-medium text-gray-400">
                    First name <span class="text-red-500">*</span>
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
                    Last name <span class="text-red-500">*</span>
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
                    Congregant ID
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

                <div class="sm:col-span-6">
                  <label for="image" class="block text-sm font-medium text-gray-400">
                    Profile Image
                  </label>
                  <div class="mt-1">
                    <div
                      id="image-upload-dropzone"
                      phx-drop-target={@uploads.image.ref}
                      phx-hook="ImageUpload"
                      class="relative border-2 border-dashed border-dark-600 rounded-lg p-6 text-center hover:border-primary-500 transition-colors cursor-pointer"
                    >
                      <.live_file_input
                        upload={@uploads.image}
                        class="hidden"
                        id="image-upload-input"
                      />

                      <%= cond do %>
                        <% !Enum.empty?(@uploads.image.entries) -> %>
                          <!-- New image being uploaded -->
                          <div :for={entry <- @uploads.image.entries}>
                            <p class="text-xs text-gray-500 mb-3">New Image Preview</p>
                            <.live_img_preview
                              entry={entry}
                              class="w-24 h-24 mx-auto rounded-full object-cover border-2 border-primary-500"
                            />
                            <div class="mt-3 flex items-center justify-center gap-3">
                              <label
                                for={@uploads.image.ref}
                                class="text-sm text-primary-500 hover:text-primary-400 cursor-pointer"
                              >
                                Change image
                              </label>
                              <span class="text-gray-600">|</span>
                              <button
                                type="button"
                                phx-click="cancel-upload"
                                phx-value-ref={entry.ref}
                                class="text-sm text-red-500 hover:text-red-400"
                              >
                                Remove
                              </button>
                            </div>
                          </div>
                        <% @congregant.image && @congregant.image != "" -> %>
                          <!-- Has existing image -->
                          <div>
                            <label for={@uploads.image.ref} class="cursor-pointer inline-block">
                              <.avatar
                                image={@congregant.image}
                                first_name={@congregant.first_name}
                                last_name={@congregant.last_name}
                                size="lg"
                                class="mx-auto border-2 border-dark-600 hover:border-primary-500 transition-colors"
                              />
                            </label>
                            <div class="mt-3 flex items-center justify-center gap-3">
                              <label
                                for={@uploads.image.ref}
                                class="text-sm text-primary-500 hover:text-primary-400 cursor-pointer"
                              >
                                Change image
                              </label>
                              <span class="text-gray-600">|</span>
                              <button
                                type="button"
                                phx-click="remove-image"
                                class="text-sm text-red-500 hover:text-red-400"
                              >
                                Remove image
                              </button>
                            </div>
                          </div>
                        <% true -> %>
                          <!-- No image - show avatar preview with upload prompt -->
                          <label for={@uploads.image.ref} class="cursor-pointer block">
                            <.avatar
                              image={nil}
                              first_name={@congregant.first_name}
                              last_name={@congregant.last_name}
                              size="lg"
                              class="mx-auto"
                            />
                            <div class="mt-4 text-sm text-gray-400">
                              <p class="font-medium">Click to upload or drag and drop</p>
                              <p class="text-xs">PNG, JPG, GIF up to 5MB</p>
                            </div>
                          </label>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Contact Information Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-phone" class="mr-2 h-5 w-5 text-primary-500" /> Contact Information
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-2">
                  <label for="mobile-tel" class="block text-sm font-medium text-gray-400">
                    Mobile Phone <span class="text-red-500">*</span>
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
                <.icon name="hero-map-pin" class="mr-2 h-5 w-5 text-primary-500" /> Address
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-6">
                  <label for="address" class="block text-sm font-medium text-gray-400">
                    Street Address <span class="text-red-500">*</span>
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
                    City <span class="text-red-500">*</span>
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
                    State <span class="text-red-500">*</span>
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
                    Zip Code <span class="text-red-500">*</span>
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
                    Membership Status <span class="text-red-500">*</span>
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
                      class="block w-full h-[42px] px-3 py-2 text-white bg-dark-900 border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>

                <div class="sm:col-span-3">
                  <label for="is-leader" class="block text-sm font-medium text-gray-400">
                    Role
                  </label>
                  <div class="mt-1 flex items-center h-[42px]">
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

            <hr class="border-dark-700" />

            <%!-- Ministries Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-user-group" class="mr-2 h-5 w-5 text-primary-500" />
                Ministries
              </h3>
              <div>
                <%!-- Hidden input to ensure ministries field is always present --%>
                <input type="hidden" name="form[ministries][]" value="" />
                <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                  <div :for={{label, value} <- @ministries_options}>
                    <label class="flex items-center space-x-2 cursor-pointer">
                      <input
                        type="checkbox"
                        name="form[ministries][]"
                        value={value}
                        checked={value in @selected_ministries}
                        class="h-4 w-4 text-primary-600 bg-dark-700 border-dark-600 rounded focus:ring-primary-500"
                      />
                      <span class="text-sm text-gray-300">{label}</span>
                    </label>
                  </div>
                </div>
                <p class="mt-3 text-xs text-gray-500">
                  Select all ministries that apply (optional)
                </p>
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
