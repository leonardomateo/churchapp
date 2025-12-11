defmodule ChurchappWeb.WeekEndingReportsLive.NewLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.ReportCategories

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Fetch all active categories grouped
    categories = fetch_categories_grouped(actor)

    # Initialize category amounts (all zeros)
    category_amounts = initialize_category_amounts(categories)

    socket =
      socket
      |> assign(:page_title, "New Week Ending Report")
      |> assign(:categories, categories)
      |> assign(:category_amounts, category_amounts)
      |> assign(:week_start_date, nil)
      |> assign(:week_end_date, nil)
      |> assign(:report_name, "")
      |> assign(:notes, "")
      |> assign(:errors, %{})
      |> assign(:show_add_category_modal, false)
      |> assign(:new_category_name, "")
      |> assign(:new_category_group, :custom)
      |> assign(:category_search, "")
      |> assign(:saving, false)

    {:ok, socket}
  end

  defp fetch_categories_grouped(actor) do
    categories =
      ReportCategories
      |> Ash.Query.for_read(:list_active, %{}, actor: actor)
      |> Ash.Query.sort([:group, :sort_order, :display_name])
      |> Ash.read!(actor: actor)

    # Group by group field
    categories
    |> Enum.group_by(& &1.group)
  end

  defp initialize_category_amounts(categories_grouped) do
    categories_grouped
    |> Enum.flat_map(fn {_group, cats} -> cats end)
    |> Enum.map(fn cat -> {cat.id, ""} end)
    |> Enum.into(%{})
  end

  def handle_event("validate", params, socket) do
    socket =
      socket
      |> assign(:week_start_date, params["week_start_date"])
      |> assign(:week_end_date, params["week_end_date"])
      |> assign(:report_name, params["report_name"] || "")
      |> assign(:notes, params["notes"] || "")

    {:noreply, socket}
  end

  def handle_event("update_amount", %{"category_id" => category_id, "value" => value}, socket) do
    # Clean and validate the amount
    cleaned_value = clean_amount(value)

    category_amounts = Map.put(socket.assigns.category_amounts, category_id, cleaned_value)

    {:noreply, assign(socket, :category_amounts, category_amounts)}
  end

  def handle_event("open_add_category_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_category_modal, true)
     |> assign(:new_category_name, "")
     |> assign(:new_category_group, :custom)
     |> assign(:category_search, "")}
  end

  def handle_event("close_add_category_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_category_modal, false)}
  end

  def handle_event("update_new_category", params, socket) do
    {:noreply,
     socket
     |> assign(:new_category_name, params["name"] || "")
     |> assign(:new_category_group, String.to_existing_atom(params["group"] || "custom"))
     |> assign(:category_search, params["search"] || "")}
  end

  def handle_event("save_new_category", _params, socket) do
    actor = socket.assigns[:current_user]
    name = socket.assigns.new_category_name
    group = socket.assigns.new_category_group

    if String.trim(name) == "" do
      {:noreply, put_flash(socket, :error, "Category name is required")}
    else
      # Create the new category
      attrs = %{
        display_name: name,
        group: group,
        is_default: false,
        is_active: true,
        sort_order: 100
      }

      case Chms.Church.create_report_category(attrs, actor: actor) do
        {:ok, new_category} ->
          # Refresh categories and add amount for new category
          categories = fetch_categories_grouped(actor)
          category_amounts = Map.put(socket.assigns.category_amounts, new_category.id, "")

          {:noreply,
           socket
           |> assign(:categories, categories)
           |> assign(:category_amounts, category_amounts)
           |> assign(:show_add_category_modal, false)
           |> put_flash(:info, "Category '#{name}' added successfully")}

        {:error, _} ->
          {:noreply,
           put_flash(socket, :error, "Failed to create category. It may already exist.")}
      end
    end
  end

  def handle_event("save", _params, socket) do
    actor = socket.assigns[:current_user]

    # Validate required fields
    errors = validate_form(socket.assigns)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :errors, errors)}
    else
      socket = assign(socket, :saving, true)

      # Parse dates
      {:ok, start_date} = Date.from_iso8601(socket.assigns.week_start_date)
      {:ok, end_date} = Date.from_iso8601(socket.assigns.week_end_date)

      # Create the report
      report_attrs = %{
        week_start_date: start_date,
        week_end_date: end_date,
        report_name:
          if(socket.assigns.report_name == "", do: nil, else: socket.assigns.report_name),
        notes: if(socket.assigns.notes == "", do: nil, else: socket.assigns.notes)
      }

      case Chms.Church.create_week_ending_report(report_attrs, actor: actor) do
        {:ok, report} ->
          # Create category entries
          create_category_entries(report, socket.assigns.category_amounts, actor)

          {:noreply,
           socket
           |> put_flash(:info, "Report created successfully")
           |> push_navigate(to: ~p"/admin/week-ending-reports")}

        {:error, changeset} ->
          error_message = extract_error_message(changeset)

          {:noreply,
           socket
           |> assign(:saving, false)
           |> put_flash(:error, error_message)}
      end
    end
  end

  defp validate_form(assigns) do
    errors = %{}

    errors =
      if is_nil(assigns.week_start_date) or assigns.week_start_date == "" do
        Map.put(errors, :week_start_date, "Start date is required")
      else
        errors
      end

    errors =
      if is_nil(assigns.week_end_date) or assigns.week_end_date == "" do
        Map.put(errors, :week_end_date, "End date is required")
      else
        errors
      end

    # Validate end date is after start date
    if assigns.week_start_date && assigns.week_end_date &&
         assigns.week_start_date != "" && assigns.week_end_date != "" do
      case {Date.from_iso8601(assigns.week_start_date), Date.from_iso8601(assigns.week_end_date)} do
        {{:ok, start_date}, {:ok, end_date}} ->
          if Date.compare(end_date, start_date) == :lt do
            Map.put(errors, :week_end_date, "End date must be on or after start date")
          else
            errors
          end

        _ ->
          errors
      end
    else
      errors
    end
  end

  defp create_category_entries(report, category_amounts, actor) do
    Enum.each(category_amounts, fn {category_id, amount_str} ->
      amount = parse_amount(amount_str)

      # Only create entry if amount is greater than 0
      if Decimal.compare(amount, Decimal.new(0)) == :gt do
        attrs = %{
          week_ending_report_id: report.id,
          report_category_id: category_id,
          amount: amount
        }

        Chms.Church.create_report_category_entry(attrs, actor: actor)
      end
    end)
  end

  defp clean_amount(value) when is_binary(value) do
    cleaned =
      value
      |> String.replace(~r/[^\d.]/, "")

    # Return empty string if no digits entered, otherwise return cleaned value
    if cleaned == "" or cleaned == "." do
      ""
    else
      cleaned
    end
  end

  defp clean_amount(_), do: ""

  defp parse_amount(value) when is_binary(value) do
    case Decimal.parse(clean_amount(value)) do
      {decimal, _} -> Decimal.round(decimal, 2)
      :error -> Decimal.new(0)
    end
  end

  defp parse_amount(_), do: Decimal.new(0)

  defp extract_error_message(%Ash.Error.Invalid{} = error) do
    error.errors
    |> Enum.map(fn e ->
      case e do
        %{message: msg} -> msg
        _ -> "Validation error"
      end
    end)
    |> Enum.join(", ")
  end

  defp extract_error_message(_), do: "An error occurred while saving"

  defp calculate_grand_total(category_amounts) do
    category_amounts
    |> Enum.map(fn {_id, amount_str} -> parse_amount(amount_str) end)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp calculate_group_subtotal(categories, category_amounts) do
    categories
    |> Enum.map(fn cat -> parse_amount(Map.get(category_amounts, cat.id, "")) end)
    |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
  end

  defp format_currency(decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> format_with_commas()
  end

  defp format_with_commas(number_string) do
    case String.split(number_string, ".") do
      [whole] ->
        format_whole_number(whole) <> ".00"

      [whole, decimal_part] ->
        format_whole_number(whole) <> "." <> String.pad_trailing(decimal_part, 2, "0")
    end
  end

  defp format_whole_number(number_string) do
    number_string
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto">
      <%!-- Header --%>
      <div class="mb-6">
        <.link
          navigate={~p"/admin/week-ending-reports"}
          class="flex items-center mb-4 text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Reports
        </.link>
        <h2 class="text-2xl font-bold text-white">New Week Ending Report</h2>
        <p class="mt-1 text-gray-400">
          Record financial data for a specific week period.
        </p>
      </div>

      <%!-- Form --%>
      <form phx-submit="save" phx-change="validate" id="week-ending-report-form">
        <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
          <div class="p-6 space-y-6">
            <%!-- Report Period Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-calendar-days" class="mr-2 h-5 w-5 text-primary-500" />
                Report Period
              </h3>
              <div class="grid grid-cols-1 gap-y-6 gap-x-4 sm:grid-cols-6">
                <div class="sm:col-span-2">
                  <label for="week_start_date" class="block text-sm font-medium text-gray-400">
                    Start Date <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <input
                      type="date"
                      id="week_start_date"
                      name="week_start_date"
                      value={@week_start_date}
                      phx-hook="DatePicker"
                      class={[
                        "block w-full px-3 py-2 text-white bg-dark-900 border rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500",
                        if(@errors[:week_start_date], do: "border-red-500", else: "border-dark-700")
                      ]}
                    />
                    <%= if @errors[:week_start_date] do %>
                      <p class="mt-1 text-sm text-red-400">{@errors[:week_start_date]}</p>
                    <% end %>
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="week_end_date" class="block text-sm font-medium text-gray-400">
                    End Date <span class="text-red-500">*</span>
                  </label>
                  <div class="mt-1">
                    <input
                      type="date"
                      id="week_end_date"
                      name="week_end_date"
                      value={@week_end_date}
                      phx-hook="DatePicker"
                      class={[
                        "block w-full px-3 py-2 text-white bg-dark-900 border rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500",
                        if(@errors[:week_end_date], do: "border-red-500", else: "border-dark-700")
                      ]}
                    />
                    <%= if @errors[:week_end_date] do %>
                      <p class="mt-1 text-sm text-red-400">{@errors[:week_end_date]}</p>
                    <% end %>
                  </div>
                </div>

                <div class="sm:col-span-2">
                  <label for="report_name" class="block text-sm font-medium text-gray-400">
                    Report Name <span class="text-gray-500">(optional)</span>
                  </label>
                  <div class="mt-1">
                    <input
                      type="text"
                      id="report_name"
                      name="report_name"
                      value={@report_name}
                      placeholder="Auto-generated if empty"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    />
                  </div>
                </div>
              </div>
            </div>

            <hr class="border-dark-700" />

            <%!-- Category Groups --%>
            <%= for group <- [:offerings, :ministries, :missions, :property, :custom] do %>
              <%= if Map.has_key?(@categories, group) and length(@categories[group]) > 0 do %>
                <div>
                  <div class="flex items-center justify-between mb-4">
                    <h3 class="flex items-center text-lg font-medium leading-6 text-white">
                      <.icon
                        name={ReportCategories.group_icon(group)}
                        class="mr-2 h-5 w-5 text-primary-500"
                      />
                      {ReportCategories.group_display_name(group)}
                    </h3>
                    <span class="text-sm text-gray-400">
                      Subtotal:
                      <span class="font-semibold text-white">
                        ${format_currency(
                          calculate_group_subtotal(@categories[group], @category_amounts)
                        )}
                      </span>
                    </span>
                  </div>
                  <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    <%= for category <- @categories[group] do %>
                      <div class="flex items-center space-x-3 p-3 bg-dark-900/50 rounded-lg border border-dark-700">
                        <label
                          for={"amount-#{category.id}"}
                          class="flex-1 text-sm font-medium text-gray-300 truncate"
                          title={category.display_name}
                        >
                          {category.display_name}
                        </label>
                        <div class="relative w-32">
                          <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-500">
                            $
                          </span>
                          <input
                            type="text"
                            id={"amount-#{category.id}"}
                            name={"amounts[#{category.id}]"}
                            value={Map.get(@category_amounts, category.id, "")}
                            phx-blur="update_amount"
                            phx-value-category_id={category.id}
                            phx-value-value={Map.get(@category_amounts, category.id, "")}
                            placeholder="0.00"
                            class="block w-full pl-7 pr-3 py-2 text-white text-right bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                          />
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>
                <hr class="border-dark-700" />
              <% end %>
            <% end %>

            <%!-- Add Category Button --%>
            <div class="flex justify-center">
              <button
                type="button"
                phx-click="open_add_category_modal"
                class="inline-flex items-center px-4 py-2 text-sm font-medium text-primary-500 bg-primary-500/10 border border-primary-500/20 rounded-md hover:bg-primary-500/20 hover:border-primary-500/30 transition-all duration-200"
              >
                <.icon name="hero-plus-circle" class="mr-2 h-5 w-5" /> Add New Category
              </button>
            </div>

            <hr class="border-dark-700" />

            <%!-- Notes Section --%>
            <div>
              <h3 class="mb-4 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-document-text" class="mr-2 h-5 w-5 text-primary-500" /> Notes
                <span class="text-gray-500 text-sm font-normal ml-2">(optional)</span>
              </h3>
              <textarea
                id="notes"
                name="notes"
                rows="3"
                placeholder="Add any additional notes about this report..."
                class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
              >{@notes}</textarea>
            </div>
          </div>

          <%!-- Grand Total & Actions --%>
          <div class="px-6 py-4 bg-dark-700/50 border-t border-dark-700">
            <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
              <div class="flex items-center space-x-2">
                <span class="text-lg font-medium text-gray-300">Grand Total:</span>
                <span class="text-3xl font-bold text-green-400">
                  ${format_currency(calculate_grand_total(@category_amounts))}
                </span>
              </div>
              <div class="flex space-x-3">
                <.link
                  navigate={~p"/admin/week-ending-reports"}
                  class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-800 border border-dark-700 rounded-md shadow-sm hover:bg-dark-700 transition-colors"
                >
                  Cancel
                </.link>
                <button
                  type="submit"
                  disabled={@saving}
                  class="px-6 py-2 text-sm font-medium text-white bg-primary-500 border border-transparent rounded-md shadow-sm hover:bg-primary-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                >
                  <%= if @saving do %>
                    <span class="flex items-center">
                      <.icon name="hero-arrow-path" class="mr-2 h-4 w-4 animate-spin" /> Saving...
                    </span>
                  <% else %>
                    Save Report
                  <% end %>
                </button>
              </div>
            </div>
          </div>
        </div>
      </form>

      <%!-- Add Category Modal --%>
      <%= if @show_add_category_modal do %>
        <div
          class="fixed inset-0 z-50 overflow-y-auto animate-fade-in"
          phx-window-keydown="close_add_category_modal"
          phx-key="escape"
        >
          <div class="flex min-h-screen items-center justify-center p-4">
            <div
              class="fixed inset-0 modal-backdrop transition-opacity"
              phx-click="close_add_category_modal"
            >
            </div>
            <div class="relative bg-dark-800 rounded-lg shadow-xl border border-dark-700 w-full max-w-md p-6 z-10 animate-scale-in">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-semibold text-white flex items-center">
                  <.icon name="hero-plus-circle" class="mr-2 h-5 w-5 text-primary-500" />
                  Add New Category
                </h3>
                <button
                  type="button"
                  phx-click="close_add_category_modal"
                  class="text-gray-400 hover:text-white transition-colors"
                >
                  <.icon name="hero-x-mark" class="h-5 w-5" />
                </button>
              </div>

              <form phx-change="update_new_category" phx-submit="save_new_category">
                <div class="space-y-4">
                  <div>
                    <label
                      for="new_category_name"
                      class="block text-sm font-medium text-gray-400 mb-1"
                    >
                      Category Name <span class="text-red-500">*</span>
                    </label>
                    <input
                      type="text"
                      id="new_category_name"
                      name="name"
                      value={@new_category_name}
                      placeholder="e.g., Special Offering"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                      phx-hook="AutoFocus"
                    />
                  </div>

                  <div>
                    <label
                      for="new_category_group"
                      class="block text-sm font-medium text-gray-400 mb-1"
                    >
                      Category Group
                    </label>
                    <select
                      id="new_category_group"
                      name="group"
                      class="block w-full px-3 py-2 text-white bg-dark-900 border border-dark-700 rounded-md shadow-sm sm:text-sm focus:ring-primary-500 focus:border-primary-500"
                    >
                      <option value="offerings" selected={@new_category_group == :offerings}>
                        Offerings
                      </option>
                      <option value="ministries" selected={@new_category_group == :ministries}>
                        Ministries
                      </option>
                      <option value="missions" selected={@new_category_group == :missions}>
                        Missions
                      </option>
                      <option value="property" selected={@new_category_group == :property}>
                        Property & Rentals
                      </option>
                      <option value="custom" selected={@new_category_group == :custom}>Custom</option>
                    </select>
                  </div>
                </div>

                <div class="mt-6 flex justify-end space-x-3">
                  <button
                    type="button"
                    phx-click="close_add_category_modal"
                    class="px-4 py-2 text-sm font-medium text-gray-300 bg-dark-700 hover:bg-dark-600 rounded-md transition-colors"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-sm transition-colors"
                  >
                    <span class="flex items-center">
                      <.icon name="hero-check" class="mr-1 h-4 w-4" /> Add Category
                    </span>
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
