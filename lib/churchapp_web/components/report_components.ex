defmodule ChurchappWeb.ReportComponents do
  @moduledoc """
  Reusable UI components for the reports interface.
  """
  use Phoenix.Component
  import ChurchappWeb.CoreComponents

  @doc """
  Resource selector dropdown component.
  """
  attr :resources, :list, required: true
  attr :selected, :atom, default: nil

  def resource_selector(assigns) do
    ~H"""
    <form phx-change="select_resource" class="w-full sm:w-auto">
      <select
        name="resource"
        class="w-full px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
      >
        <option value="">Select a Resource...</option>
        <%= for resource <- @resources do %>
          <option value={resource.key} selected={resource.key == @selected}>
            {resource.name}
          </option>
        <% end %>
      </select>
    </form>
    """
  end

  @doc """
  Filters panel with dynamic filter inputs.
  """
  attr :resource_config, :map, required: true
  attr :filter_params, :map, required: true
  attr :has_active_filters, :boolean, required: true

  def filters_panel(assigns) do
    ~H"""
    <div class="bg-dark-800 border border-dark-700 rounded-lg p-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-sm font-medium text-white flex items-center">
          <.icon name="hero-funnel" class="mr-2 h-4 w-4 text-primary-500" /> Filters
        </h3>
        <%= if @has_active_filters do %>
          <button
            type="button"
            phx-click="clear_filters"
            class="text-xs text-gray-400 hover:text-white transition-colors"
          >
            Clear All
          </button>
        <% end %>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <%= for filter <- @resource_config.filters do %>
          <.filter_input
            filter={filter}
            value={Map.get(@filter_params, to_string(filter.key), "")}
          />
        <% end %>
      </div>
    </div>
    """
  end

  @doc """
  Individual filter input component - polymorphic based on type.
  """
  attr :filter, :map, required: true
  attr :value, :any, required: true

  def filter_input(%{filter: %{type: :text}} = assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-400 mb-1">
        {@filter.label}
      </label>
      <input
        type="text"
        phx-change="update_filter"
        phx-value-filter={@filter.key}
        phx-debounce="300"
        name="value"
        value={@value}
        placeholder={@filter[:placeholder] || ""}
        class="w-full px-3 py-2 text-sm text-gray-200 placeholder-gray-500 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
      />
    </div>
    """
  end

  def filter_input(%{filter: %{type: :select}} = assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-400 mb-1">
        {@filter.label}
      </label>
      <select
        phx-change="update_filter"
        phx-value-filter={@filter.key}
        name="value"
        class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-800 transition-colors cursor-pointer"
      >
        <option value="">All</option>
        <%= for option <- @filter.options do %>
          <option value={option} selected={to_string(option) == @value}>
            {format_option_label(option)}
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  def filter_input(%{filter: %{type: :date}} = assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-400 mb-1">
        {@filter.label}
      </label>
      <input
        type="date"
        id={"filter-#{@filter.key}"}
        phx-change="update_filter"
        phx-value-filter={@filter.key}
        phx-hook="DatePicker"
        name="value"
        value={@value}
        class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
      />
    </div>
    """
  end

  def filter_input(%{filter: %{type: :number}} = assigns) do
    ~H"""
    <div>
      <label class="block text-xs font-medium text-gray-400 mb-1">
        {@filter.label}
      </label>
      <input
        type="number"
        phx-change="update_filter"
        phx-value-filter={@filter.key}
        phx-debounce="300"
        name="value"
        value={@value}
        step="0.01"
        class="w-full px-3 py-2 text-sm text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
      />
    </div>
    """
  end

  def filter_input(%{filter: %{type: :boolean}} = assigns) do
    ~H"""
    <div>
      <label class="flex items-center">
        <input
          type="checkbox"
          phx-click="update_filter"
          phx-value-filter={@filter.key}
          phx-value-value={if @value in ["true", true], do: "false", else: "true"}
          checked={@value in ["true", true]}
          class="h-4 w-4 text-primary-500 bg-dark-900 border-dark-700 rounded focus:ring-2 focus:ring-primary-500"
        />
        <span class="ml-2 text-sm text-gray-300">{@filter.label}</span>
      </label>
    </div>
    """
  end

  @doc """
  Results table with sortable headers.
  """
  attr :resource_config, :map, required: true
  attr :results, :list, required: true
  attr :sort_by, :atom, required: true
  attr :sort_dir, :atom, required: true

  def results_table(assigns) do
    ~H"""
    <div class="overflow-x-auto bg-dark-800 border border-dark-700 rounded-lg">
      <table class="min-w-full divide-y divide-dark-700">
        <thead class="bg-dark-900">
          <tr>
            <%= for field <- @resource_config.fields do %>
              <th
                scope="col"
                class={[
                  "px-6 py-3 text-left text-xs font-medium text-gray-400 uppercase tracking-wider",
                  field.key in @resource_config.sortable_fields &&
                    "cursor-pointer hover:text-white transition-colors"
                ]}
                phx-click={field.key in @resource_config.sortable_fields && "sort"}
                phx-value-field={field.key}
              >
                <div class="flex items-center gap-2">
                  <span>{field.label}</span>
                  <%= if field.key == @sort_by do %>
                    <.icon
                      name={if @sort_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"}
                      class="h-4 w-4 text-primary-500"
                    />
                  <% end %>
                </div>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody class="bg-dark-800 divide-y divide-dark-700">
          <%= for result <- @results do %>
            <tr class="hover:bg-dark-700 transition-colors">
              <%= for field <- @resource_config.fields do %>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-300">
                  <.field_value result={result} field={field} />
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Format field value based on type.
  """
  attr :result, :map, required: true
  attr :field, :map, required: true

  def field_value(assigns) do
    value = get_field_value(assigns.result, assigns.field)
    formatted = format_value(value, assigns.field.type)
    assigns = assign(assigns, :formatted_value, formatted)

    ~H"""
    {@formatted_value}
    """
  end

  defp get_field_value(result, field) do
    # Handle computed fields
    case field do
      %{computed: true, key: :congregant_name} ->
        # For contributions - get congregant name
        if congregant = Map.get(result, :congregant) do
          "#{congregant.first_name} #{congregant.last_name}"
        else
          ""
        end

      _ ->
        Map.get(result, field.key)
    end
  end

  defp format_value(nil, _type), do: ""
  defp format_value("", _type), do: ""

  defp format_value(value, :currency) do
    "$#{Decimal.to_string(value, :normal)}"
  end

  defp format_value(value, :datetime) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")
  end

  defp format_value(value, :date) do
    Date.to_string(value)
  end

  defp format_value(value, :boolean) do
    if value, do: "Yes", else: "No"
  end

  defp format_value(value, :array) when is_list(value) do
    Enum.join(value, "; ")
  end

  defp format_value(value, :atom) when is_atom(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_value(value, _type), do: to_string(value)

  @doc """
  Pagination component.
  """
  attr :page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :pagination_range, :list, required: true

  def pagination(assigns) do
    ~H"""
    <nav class="flex items-center justify-center">
      <ul class="flex items-center gap-1">
        <%!-- Previous Button --%>
        <%= if @page > 1 do %>
          <li>
            <button
              type="button"
              phx-click="paginate"
              phx-value-page={@page - 1}
              class="px-3 py-2 text-sm text-gray-300 bg-dark-800 border border-dark-700 rounded-md hover:bg-dark-700 hover:text-white transition-colors"
            >
              <.icon name="hero-chevron-left" class="h-4 w-4" />
            </button>
          </li>
        <% end %>

        <%!-- Page Numbers --%>
        <%= for page_item <- @pagination_range do %>
          <%= if page_item == :ellipsis do %>
            <li>
              <span class="px-3 py-2 text-sm text-gray-500">...</span>
            </li>
          <% else %>
            <li>
              <button
                type="button"
                phx-click="paginate"
                phx-value-page={page_item}
                class={[
                  "px-3 py-2 text-sm rounded-md transition-colors",
                  if(page_item == @page,
                    do:
                      "text-white bg-primary-500 hover:bg-primary-600 font-medium shadow-lg shadow-primary-500/20",
                    else:
                      "text-gray-300 bg-dark-800 border border-dark-700 hover:bg-dark-700 hover:text-white"
                  )
                ]}
              >
                {page_item}
              </button>
            </li>
          <% end %>
        <% end %>

        <%!-- Next Button --%>
        <%= if @page < @total_pages do %>
          <li>
            <button
              type="button"
              phx-click="paginate"
              phx-value-page={@page + 1}
              class="px-3 py-2 text-sm text-gray-300 bg-dark-800 border border-dark-700 rounded-md hover:bg-dark-700 hover:text-white transition-colors"
            >
              <.icon name="hero-chevron-right" class="h-4 w-4" />
            </button>
          </li>
        <% end %>
      </ul>
    </nav>
    """
  end

  @doc """
  Loading spinner component.
  """
  def loading_spinner(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-3">
      <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-500"></div>
      <p class="text-sm text-gray-400">Generating report...</p>
    </div>
    """
  end

  # Template Components

  @doc """
  Template selector dropdown for quick template loading.
  """
  attr :templates, :list, required: true

  def template_selector(assigns) do
    ~H"""
    <form phx-change="load_template" class="w-full sm:w-auto">
      <select
        name="id"
        class="w-full px-4 py-2 text-gray-200 bg-dark-800 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent hover:bg-dark-700 hover:border-dark-600 transition-colors cursor-pointer"
      >
        <option value="">Load Template...</option>
        <%= for template <- @templates do %>
          <option value={template.id}>
            {template.name}
            <%= if template.is_shared do %>
              (shared)
            <% end %>
          </option>
        <% end %>
      </select>
    </form>
    """
  end

  @doc """
  Modal for saving a new template or editing an existing one.
  """
  attr :form, :map, required: true
  attr :editing_id, :any, default: nil

  def save_template_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      phx-click="close_save_template_modal"
    >
      <div
        class="bg-dark-800 border border-dark-700 rounded-lg w-full max-w-md"
        phx-click-away="close_save_template_modal"
      >
        <div class="flex items-center justify-between px-6 py-4 border-b border-dark-700">
          <h3 class="text-lg font-medium text-white">
            {if @editing_id, do: "Edit Template", else: "Save Template"}
          </h3>
          <button
            type="button"
            phx-click="close_save_template_modal"
            class="text-gray-400 hover:text-white transition-colors"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <form phx-submit={if @editing_id, do: "update_template", else: "save_template"}>
          <div class="px-6 py-4 space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">
                Template Name <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                name="template[name]"
                value={@form["name"]}
                required
                maxlength="100"
                class="w-full px-3 py-2 text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                placeholder="e.g., Monthly Active Members"
              />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-300 mb-1">
                Description
              </label>
              <textarea
                name="template[description]"
                maxlength="500"
                rows="3"
                class="w-full px-3 py-2 text-gray-200 bg-dark-900 border border-dark-700 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
                placeholder="Optional description of what this template includes..."
              >{@form["description"]}</textarea>
            </div>

            <div class="flex items-center">
              <input
                type="checkbox"
                name="template[is_shared]"
                id="is_shared"
                value="true"
                checked={@form["is_shared"]}
                class="h-4 w-4 text-primary-500 bg-dark-900 border-dark-700 rounded focus:ring-2 focus:ring-primary-500"
              />
              <label for="is_shared" class="ml-2 text-sm text-gray-300">
                Share with all admins
              </label>
            </div>

            <div class="bg-dark-900 border border-dark-700 rounded-md p-3">
              <p class="text-xs text-gray-400">
                <.icon name="hero-information-circle" class="inline h-4 w-4 mr-1" />
                This template will save your current filters and sorting preferences.
              </p>
            </div>
          </div>

          <div class="flex justify-end gap-3 px-6 py-4 border-t border-dark-700 bg-dark-900/50">
            <button
              type="button"
              phx-click="close_save_template_modal"
              class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
            >
              {if @editing_id, do: "Update Template", else: "Save Template"}
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  @doc """
  Modal for managing saved templates.
  """
  attr :templates, :list, required: true
  attr :current_user, :map, required: true

  def manage_templates_modal(assigns) do
    ~H"""
    <div
      class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4"
      phx-click="close_manage_templates"
    >
      <div
        class="bg-dark-800 border border-dark-700 rounded-lg w-full max-w-2xl max-h-[80vh] flex flex-col"
        phx-click-away="close_manage_templates"
      >
        <div class="flex items-center justify-between px-6 py-4 border-b border-dark-700">
          <h3 class="text-lg font-medium text-white">Manage Templates</h3>
          <button
            type="button"
            phx-click="close_manage_templates"
            class="text-gray-400 hover:text-white transition-colors"
          >
            <.icon name="hero-x-mark" class="h-5 w-5" />
          </button>
        </div>

        <div class="flex-1 overflow-y-auto p-6">
          <%= if length(@templates) == 0 do %>
            <div class="text-center py-8">
              <.icon name="hero-bookmark" class="mx-auto h-12 w-12 text-gray-500 mb-3" />
              <p class="text-gray-400">No saved templates yet.</p>
              <p class="text-sm text-gray-500 mt-1">
                Use "Save Template" to save your current filter configuration.
              </p>
            </div>
          <% else %>
            <div class="space-y-3">
              <%= for template <- @templates do %>
                <.template_card template={template} current_user={@current_user} />
              <% end %>
            </div>
          <% end %>
        </div>

        <div class="flex justify-end px-6 py-4 border-t border-dark-700 bg-dark-900/50">
          <button
            type="button"
            phx-click="close_manage_templates"
            class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 border border-dark-600 rounded-md hover:bg-dark-600 transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Individual template card for the manage templates modal.
  """
  attr :template, :map, required: true
  attr :current_user, :map, required: true

  def template_card(assigns) do
    is_owner = assigns.template.created_by_id == assigns.current_user.id
    can_modify = is_owner || assigns.current_user.role == :super_admin
    assigns = assign(assigns, :is_owner, is_owner)
    assigns = assign(assigns, :can_modify, can_modify)

    ~H"""
    <div class="bg-dark-900 border border-dark-700 rounded-lg p-4 hover:border-dark-600 transition-colors">
      <div class="flex items-start justify-between">
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2">
            <h4 class="text-sm font-medium text-white truncate">{@template.name}</h4>
            <%= if @template.is_shared do %>
              <span class="inline-flex items-center px-2 py-0.5 text-xs font-medium text-primary-400 bg-primary-500/10 rounded-full">
                <.icon name="hero-users" class="h-3 w-3 mr-1" /> Shared
              </span>
            <% else %>
              <span class="inline-flex items-center px-2 py-0.5 text-xs font-medium text-gray-400 bg-dark-700 rounded-full">
                <.icon name="hero-lock-closed" class="h-3 w-3 mr-1" /> Private
              </span>
            <% end %>
          </div>

          <%= if @template.description && @template.description != "" do %>
            <p class="mt-1 text-xs text-gray-400 line-clamp-2">{@template.description}</p>
          <% end %>

          <p class="mt-2 text-xs text-gray-500">
            Created {format_date(@template.inserted_at)}
            <%= unless @is_owner do %>
              by another admin
            <% end %>
          </p>
        </div>

        <div class="flex items-center gap-1 ml-4">
          <button
            type="button"
            phx-click="load_template"
            phx-value-id={@template.id}
            class="p-2 text-gray-400 hover:text-primary-400 hover:bg-dark-700 rounded-md transition-colors"
            title="Load template"
          >
            <.icon name="hero-play" class="h-4 w-4" />
          </button>

          <%= if @can_modify do %>
            <button
              type="button"
              phx-click="edit_template"
              phx-value-id={@template.id}
              class="p-2 text-gray-400 hover:text-white hover:bg-dark-700 rounded-md transition-colors"
              title="Edit template"
            >
              <.icon name="hero-pencil" class="h-4 w-4" />
            </button>

            <button
              type="button"
              phx-click="toggle_template_share"
              phx-value-id={@template.id}
              class="p-2 text-gray-400 hover:text-white hover:bg-dark-700 rounded-md transition-colors"
              title={if @template.is_shared, do: "Make private", else: "Share with admins"}
            >
              <.icon
                name={if @template.is_shared, do: "hero-lock-closed", else: "hero-share"}
                class="h-4 w-4"
              />
            </button>

            <button
              type="button"
              phx-click="delete_template"
              phx-value-id={@template.id}
              data-confirm="Are you sure you want to delete this template?"
              class="p-2 text-gray-400 hover:text-red-400 hover:bg-dark-700 rounded-md transition-colors"
              title="Delete template"
            >
              <.icon name="hero-trash" class="h-4 w-4" />
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_option_label(option) when is_atom(option) do
    option
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_option_label(option), do: to_string(option)

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end
end
