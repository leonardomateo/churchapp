defmodule ChurchappWeb.AttendanceCategoriesLive.EditLive do
  use ChurchappWeb, :live_view

  alias AshPhoenix.Form

  def mount(%{"id" => id}, _session, socket) do
    case Chms.Church.get_attendance_category_by_id(id) do
      {:ok, category} ->
        form =
          category
          |> Form.for_update(:update, domain: Chms.Church, actor: socket.assigns.current_user)
          |> to_form()

        socket =
          socket
          |> assign(:page_title, "Edit #{category.name}")
          |> assign(:category, category)
          |> assign(:form, form)

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Category not found")
         |> push_navigate(to: ~p"/admin/attendance-categories")}
    end
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> Form.validate(params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form.source, params: params) do
      {:ok, category} ->
        {:noreply,
         socket
         |> put_flash(:info, "Category \"#{category.name}\" updated successfully")
         |> push_navigate(to: ~p"/admin/attendance-categories")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="view-container active">
      <div class="mb-6">
        <.link
          navigate={~p"/admin/attendance-categories"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Categories
        </.link>
      </div>

      <div class="max-w-2xl mx-auto">
        <div class="mb-6">
          <h2 class="text-2xl font-bold text-white">Edit Category</h2>
          <p class="mt-1 text-sm text-gray-400">
            Update the attendance category settings
          </p>
        </div>

        <%= if @category.is_system do %>
          <div class="mb-6 p-4 bg-blue-900/20 border border-blue-500/30 rounded-lg">
            <div class="flex items-center">
              <.icon name="hero-information-circle" class="h-5 w-5 text-blue-400 mr-3" />
              <p class="text-sm text-blue-300">
                This is a system category. You can edit its name, description, and color, but it cannot be deleted.
              </p>
            </div>
          </div>
        <% end %>

        <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
          <.form
            for={@form}
            id="category-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-6"
          >
            <div>
              <label for={@form[:name].id} class="block text-sm font-medium text-gray-300 mb-2">
                Category Name <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                id={@form[:name].id}
                name={@form[:name].name}
                value={@form[:name].value}
                placeholder="e.g., Sunday School, Prayer Meeting"
                class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
              <.field_errors field={@form[:name]} />
            </div>

            <div>
              <label for={@form[:description].id} class="block text-sm font-medium text-gray-300 mb-2">
                Description
              </label>
              <textarea
                id={@form[:description].id}
                name={@form[:description].name}
                rows="3"
                placeholder="Optional description for this category..."
                class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
              >{@form[:description].value}</textarea>
            </div>

            <div>
              <label for={@form[:color].id} class="block text-sm font-medium text-gray-300 mb-2">
                Color <span class="text-red-500">*</span>
              </label>
              <div class="flex items-center gap-4">
                <input
                  type="color"
                  id={@form[:color].id}
                  name={@form[:color].name}
                  value={@form[:color].value || "#06b6d4"}
                  class="h-12 w-20 bg-dark-700 border border-dark-600 rounded cursor-pointer"
                />
                <div class="flex flex-wrap gap-2">
                  <.color_preset color="#06b6d4" label="Cyan" form={@form} />
                  <.color_preset color="#8b5cf6" label="Purple" form={@form} />
                  <.color_preset color="#3b82f6" label="Blue" form={@form} />
                  <.color_preset color="#ec4899" label="Pink" form={@form} />
                  <.color_preset color="#f59e0b" label="Amber" form={@form} />
                  <.color_preset color="#10b981" label="Emerald" form={@form} />
                  <.color_preset color="#ef4444" label="Red" form={@form} />
                  <.color_preset color="#6b7280" label="Gray" form={@form} />
                </div>
              </div>
              <.field_errors field={@form[:color]} />
            </div>

            <div>
              <label
                for={@form[:display_order].id}
                class="block text-sm font-medium text-gray-300 mb-2"
              >
                Display Order
              </label>
              <input
                type="number"
                id={@form[:display_order].id}
                name={@form[:display_order].name}
                value={@form[:display_order].value}
                min="1"
                class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              />
              <p class="mt-1 text-xs text-gray-500">
                Lower numbers appear first in lists
              </p>
            </div>

            <div class="flex items-center justify-end gap-3 pt-4 border-t border-dark-600">
              <.link
                navigate={~p"/admin/attendance-categories"}
                class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md border border-dark-600 transition-colors"
              >
                Cancel
              </.link>
              <button
                type="submit"
                class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
              >
                Save Changes
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end

  defp color_preset(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={JS.set_attribute({"value", @color}, to: "##{@form[:color].id}")}
      class={[
        "w-8 h-8 rounded-full border-2 transition-all hover:scale-110",
        @form[:color].value == @color && "border-white ring-2 ring-white/50",
        @form[:color].value != @color && "border-dark-600 hover:border-dark-500"
      ]}
      style={"background-color: #{@color};"}
      title={@label}
    >
    </button>
    """
  end

  defp field_errors(assigns) do
    ~H"""
    <p
      :for={msg <- get_field_errors(@field)}
      class="mt-1.5 flex gap-2 items-center text-sm text-red-400"
    >
      <.icon name="hero-exclamation-circle" class="h-5 w-5" />
      {msg}
    </p>
    """
  end

  defp get_field_errors(field) do
    case field.errors do
      errors when is_list(errors) ->
        Enum.map(errors, fn
          {msg, _opts} -> msg
          msg when is_binary(msg) -> msg
          _ -> "Invalid"
        end)

      _ ->
        []
    end
  end
end
