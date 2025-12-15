defmodule ChurchappWeb.AttendanceLive.NewLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]

    # Load categories
    categories =
      case Chms.Church.list_active_attendance_categories(actor: actor) do
        {:ok, cats} -> cats
        _ -> []
      end

    # Load congregants
    congregants =
      case Chms.Church.list_congregants(actor: actor) do
        {:ok, list} ->
          list
          |> Enum.filter(&(&1.status == :member))
          |> Enum.sort_by(&"#{&1.first_name} #{&1.last_name}")

        _ ->
          []
      end

    # Default datetime to now
    now = DateTime.utc_now()
    default_date = DateTime.to_date(now) |> Date.to_iso8601()
    default_time = "10:00"

    # Build category options for the select
    category_options =
      [{"Select a category...", ""}] ++
        Enum.map(categories, fn cat -> {cat.name, cat.id} end)

    socket =
      socket
      |> assign(:page_title, "Record Attendance")
      |> assign(:categories, categories)
      |> assign(:category_options, category_options)
      |> assign(:congregants, congregants)
      |> assign(:form_data, %{
        "category_id" => "",
        "session_date" => default_date,
        "session_time" => default_time,
        "notes" => "",
        "manual_count" => ""
      })
      |> assign(:attendance_mode, "individual")
      |> assign(:selected_congregant_ids, MapSet.new())
      |> assign(:search_query, "")
      |> assign(:form_errors, %{})

    {:ok, socket}
  end

  def handle_event("validate", %{"attendance" => params}, socket) do
    # Update form data with all incoming params
    form_data =
      socket.assigns.form_data
      |> Map.merge(params)

    # Clear errors for fields that now have values
    form_errors = socket.assigns.form_errors

    form_errors =
      if Map.get(params, "category_id", "") != "" do
        Map.delete(form_errors, :category)
      else
        form_errors
      end

    form_errors =
      if Map.get(params, "session_date", "") != "" do
        Map.delete(form_errors, :date)
      else
        form_errors
      end

    form_errors =
      if Map.get(params, "session_time", "") != "" do
        Map.delete(form_errors, :time)
      else
        form_errors
      end

    # Clear manual_count error if it has a value
    form_errors =
      if Map.get(params, "manual_count", "") != "" do
        Map.delete(form_errors, :manual_count)
      else
        form_errors
      end

    {:noreply,
     socket
     |> assign(:form_data, form_data)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("set_attendance_mode", %{"mode" => mode}, socket) do
    # Clear mode-specific errors when switching
    form_errors =
      socket.assigns.form_errors
      |> Map.delete(:congregants)
      |> Map.delete(:manual_count)

    {:noreply,
     socket
     |> assign(:attendance_mode, mode)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("search_congregants", %{"query" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  def handle_event("toggle_congregant", %{"id" => id}, socket) do
    selected = socket.assigns.selected_congregant_ids

    new_selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    # Clear congregants error when selecting
    form_errors =
      if MapSet.size(new_selected) > 0 do
        Map.delete(socket.assigns.form_errors, :congregants)
      else
        socket.assigns.form_errors
      end

    {:noreply,
     socket
     |> assign(:selected_congregant_ids, new_selected)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("select_all", _params, socket) do
    filtered = filtered_congregants(socket.assigns.congregants, socket.assigns.search_query)
    all_ids = filtered |> Enum.map(& &1.id) |> MapSet.new()
    current = socket.assigns.selected_congregant_ids
    new_selected = MapSet.union(current, all_ids)

    form_errors = Map.delete(socket.assigns.form_errors, :congregants)

    {:noreply,
     socket
     |> assign(:selected_congregant_ids, new_selected)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("deselect_all", _params, socket) do
    filtered = filtered_congregants(socket.assigns.congregants, socket.assigns.search_query)
    filtered_ids = filtered |> Enum.map(& &1.id) |> MapSet.new()
    current = socket.assigns.selected_congregant_ids
    new_selected = MapSet.difference(current, filtered_ids)
    {:noreply, assign(socket, :selected_congregant_ids, new_selected)}
  end

  def handle_event("save", %{"attendance" => params}, socket) do
    # Merge any final params
    form_data = Map.merge(socket.assigns.form_data, params)
    mode = socket.assigns.attendance_mode
    errors = validate_form(form_data, socket.assigns.selected_congregant_ids, mode)

    if map_size(errors) > 0 do
      {:noreply,
       socket
       |> assign(:form_data, form_data)
       |> assign(:form_errors, errors)}
    else
      # Create the session
      case create_session_with_records(form_data, socket, mode) do
        {:ok, session} ->
          success_message =
            if mode == "headcount" do
              "Attendance recorded successfully with #{form_data["manual_count"]} attendees"
            else
              "Attendance recorded successfully for #{MapSet.size(socket.assigns.selected_congregant_ids)} congregants"
            end

          {:noreply,
           socket
           |> put_flash(:info, success_message)
           |> push_navigate(to: ~p"/attendance/#{session.id}")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:error, message)
           |> assign(:form_errors, %{})}
      end
    end
  end

  defp validate_form(form_data, selected_congregant_ids, mode) do
    errors = %{}

    errors =
      if form_data["category_id"] == "" do
        Map.put(errors, :category, "Please select a category")
      else
        errors
      end

    errors =
      if form_data["session_date"] == "" do
        Map.put(errors, :date, "Please select a date")
      else
        errors
      end

    errors =
      if form_data["session_time"] == "" do
        Map.put(errors, :time, "Please select a time")
      else
        errors
      end

    # Mode-specific validation
    errors =
      case mode do
        "headcount" ->
          manual_count = form_data["manual_count"] || ""

          cond do
            manual_count == "" ->
              Map.put(errors, :manual_count, "Please enter the attendance count")

            not valid_positive_integer?(manual_count) ->
              Map.put(errors, :manual_count, "Please enter a valid positive number")

            true ->
              errors
          end

        _ ->
          if MapSet.size(selected_congregant_ids) == 0 do
            Map.put(errors, :congregants, "Please select at least one congregant")
          else
            errors
          end
      end

    errors
  end

  defp valid_positive_integer?(value) do
    case Integer.parse(value) do
      {num, ""} when num > 0 -> true
      _ -> false
    end
  end

  defp create_session_with_records(form_data, socket, mode) do
    actor = socket.assigns[:current_user]

    # Parse datetime
    datetime =
      case DateTime.new(
             Date.from_iso8601!(form_data["session_date"]),
             Time.from_iso8601!("#{form_data["session_time"]}:00"),
             "Etc/UTC"
           ) do
        {:ok, dt} -> dt
        _ -> DateTime.utc_now()
      end

    session_attrs = %{
      category_id: form_data["category_id"],
      session_datetime: datetime,
      notes: form_data["notes"]
    }

    case Chms.Church.create_attendance_session(session_attrs, actor: actor) do
      {:ok, session} ->
        case mode do
          "headcount" ->
            # Headcount mode: just set the total_present directly
            {count, _} = Integer.parse(form_data["manual_count"])
            Chms.Church.update_attendance_session_total(session, count, actor: actor)

          _ ->
            # Individual mode: create attendance records for each selected congregant
            selected_ids = MapSet.to_list(socket.assigns.selected_congregant_ids)

            Enum.each(selected_ids, fn congregant_id ->
              record_attrs = %{
                session_id: session.id,
                congregant_id: congregant_id,
                present: true
              }

              Chms.Church.create_attendance_record(record_attrs, actor: actor)
            end)

            # Update the total_present count
            Chms.Church.update_attendance_session_total(session, length(selected_ids), actor: actor)
        end

        {:ok, session}

      {:error, _changeset} ->
        {:error, "Failed to create attendance session"}
    end
  end

  defp filtered_congregants(congregants, "") do
    congregants
  end

  defp filtered_congregants(congregants, query) do
    query_lower = String.downcase(query)

    Enum.filter(congregants, fn c ->
      full_name = "#{c.first_name} #{c.last_name}" |> String.downcase()
      String.contains?(full_name, query_lower)
    end)
  end

  def render(assigns) do
    filtered = filtered_congregants(assigns.congregants, assigns.search_query)
    assigns = assign(assigns, :filtered_congregants, filtered)

    ~H"""
    <div class="view-container active">
      <div class="mb-6">
        <.link
          navigate={~p"/attendance"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Attendance
        </.link>
      </div>

      <div class="max-w-4xl mx-auto">
        <div class="mb-6">
          <h2 class="text-2xl font-bold text-white">Record Attendance</h2>
          <p class="mt-1 text-sm text-gray-400">
            Select the category, date, and record attendance
          </p>
        </div>

        <%!-- Attendance Mode Toggle --%>
        <div class="mb-6 bg-dark-800 rounded-lg border border-dark-700 p-4">
          <label class="block text-sm font-medium text-gray-300 mb-3">
            Attendance Mode
          </label>
          <div class="flex gap-2">
            <button
              type="button"
              phx-click="set_attendance_mode"
              phx-value-mode="individual"
              class={[
                "flex-1 px-4 py-2 text-sm font-medium rounded-md transition-colors",
                @attendance_mode == "individual" &&
                  "bg-primary-500 text-white",
                @attendance_mode != "individual" &&
                  "bg-dark-700 text-gray-400 hover:bg-dark-600 hover:text-white"
              ]}
            >
              <.icon name="hero-user-group" class="h-4 w-4 inline mr-2" />
              Individual (Select Names)
            </button>
            <button
              type="button"
              phx-click="set_attendance_mode"
              phx-value-mode="headcount"
              class={[
                "flex-1 px-4 py-2 text-sm font-medium rounded-md transition-colors",
                @attendance_mode == "headcount" &&
                  "bg-primary-500 text-white",
                @attendance_mode != "headcount" &&
                  "bg-dark-700 text-gray-400 hover:bg-dark-600 hover:text-white"
              ]}
            >
              <.icon name="hero-calculator" class="h-4 w-4 inline mr-2" />
              Headcount (Total Only)
            </button>
          </div>
          <p class="mt-2 text-xs text-gray-500">
            <%= if @attendance_mode == "individual" do %>
              Select individual congregants to mark as present
            <% else %>
              Enter just the total attendance count without individual names
            <% end %>
          </p>
        </div>

        <.form
          for={%{}}
          as={:attendance}
          id="attendance-form"
          phx-change="validate"
          phx-submit="save"
        >
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <%!-- Left Column: Session Details --%>
            <div class="lg:col-span-1 space-y-6">
              <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
                <h3 class="text-lg font-semibold text-white mb-4">Session Details</h3>

                <%!-- Category Selection --%>
                <div class="mb-4">
                  <label for="category_id" class="block text-sm font-medium text-gray-300 mb-2">
                    Category <span class="text-red-500">*</span>
                  </label>
                  <select
                    id="category_id"
                    name="attendance[category_id]"
                    class={[
                      "w-full px-4 py-2 text-gray-200 bg-dark-700 border rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent cursor-pointer",
                      @form_errors[:category] && "border-red-500",
                      !@form_errors[:category] && "border-dark-600"
                    ]}
                  >
                    <%= for {label, value} <- @category_options do %>
                      <option value={value} selected={@form_data["category_id"] == value}>
                        {label}
                      </option>
                    <% end %>
                  </select>
                  <p :if={@form_errors[:category]} class="mt-1 text-sm text-red-400">
                    {@form_errors[:category]}
                  </p>
                </div>

                <%!-- Date Selection --%>
                <div class="mb-4">
                  <label for="session_date" class="block text-sm font-medium text-gray-300 mb-2">
                    Date <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="date"
                    id="session_date"
                    name="attendance[session_date]"
                    value={@form_data["session_date"]}
                    phx-hook="DatePickerClose"
                    class={[
                      "w-full h-[38px] px-4 text-gray-200 bg-dark-700 border rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent",
                      @form_errors[:date] && "border-red-500",
                      !@form_errors[:date] && "border-dark-600"
                    ]}
                  />
                  <p :if={@form_errors[:date]} class="mt-1 text-sm text-red-400">
                    {@form_errors[:date]}
                  </p>
                </div>

                <%!-- Time Selection --%>
                <div class="mb-4">
                  <label for="session_time" class="block text-sm font-medium text-gray-300 mb-2">
                    Time <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="time"
                    id="session_time"
                    name="attendance[session_time]"
                    value={@form_data["session_time"]}
                    phx-hook="DatePickerClose"
                    class={[
                      "w-full h-[38px] px-4 text-gray-200 bg-dark-700 border rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent",
                      @form_errors[:time] && "border-red-500",
                      !@form_errors[:time] && "border-dark-600"
                    ]}
                  />
                  <p :if={@form_errors[:time]} class="mt-1 text-sm text-red-400">
                    {@form_errors[:time]}
                  </p>
                </div>

                <%!-- Notes --%>
                <div>
                  <label for="notes" class="block text-sm font-medium text-gray-300 mb-2">
                    Notes
                  </label>
                  <textarea
                    id="notes"
                    name="attendance[notes]"
                    rows="3"
                    placeholder="Optional session notes..."
                    class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
                  >{@form_data["notes"]}</textarea>
                </div>
              </div>

              <%!-- Headcount Input (only in headcount mode) --%>
              <div :if={@attendance_mode == "headcount"} class="bg-dark-800 rounded-lg border border-dark-700 p-6">
                <h3 class="text-lg font-semibold text-white mb-4">Total Attendance</h3>
                <div>
                  <label for="manual_count" class="block text-sm font-medium text-gray-300 mb-2">
                    Number of Attendees <span class="text-red-500">*</span>
                  </label>
                  <input
                    type="number"
                    id="manual_count"
                    name="attendance[manual_count]"
                    min="1"
                    value={@form_data["manual_count"]}
                    placeholder="Enter total count..."
                    class={[
                      "w-full px-4 py-3 text-2xl font-bold text-center text-gray-200 bg-dark-700 border rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent",
                      @form_errors[:manual_count] && "border-red-500",
                      !@form_errors[:manual_count] && "border-dark-600"
                    ]}
                  />
                  <p :if={@form_errors[:manual_count]} class="mt-1 text-sm text-red-400">
                    {@form_errors[:manual_count]}
                  </p>
                </div>
              </div>

              <%!-- Summary Card --%>
              <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
                <h3 class="text-lg font-semibold text-white mb-4">Summary</h3>
                <div class="space-y-3">
                  <div class="flex justify-between items-center">
                    <span class="text-gray-400">
                      <%= if @attendance_mode == "headcount", do: "Total", else: "Selected" %>
                    </span>
                    <span class="text-2xl font-bold text-primary-500">
                      <%= if @attendance_mode == "headcount" do %>
                        <%= if @form_data["manual_count"] != "", do: @form_data["manual_count"], else: "0" %>
                      <% else %>
                        {MapSet.size(@selected_congregant_ids)}
                      <% end %>
                    </span>
                  </div>
                  <div :if={@attendance_mode == "individual"} class="flex justify-between items-center text-sm">
                    <span class="text-gray-500">Total congregants</span>
                    <span class="text-gray-400">{length(@congregants)}</span>
                  </div>
                </div>
                <button
                  type="submit"
                  class="w-full mt-6 px-4 py-3 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
                >
                  <.icon name="hero-check" class="mr-2 h-4 w-4 inline" /> Save Attendance
                </button>
              </div>
            </div>

            <%!-- Right Column: Congregant Selection (only in individual mode) --%>
            <div :if={@attendance_mode == "individual"} class="lg:col-span-2">
              <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
                <div class="flex items-center justify-between mb-4">
                  <h3 class="text-lg font-semibold text-white">
                    Mark Present <span class="text-red-500">*</span>
                  </h3>
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      phx-click="select_all"
                      class="px-3 py-1 text-xs font-medium text-primary-400 hover:text-primary-300 bg-primary-500/10 hover:bg-primary-500/20 rounded transition-colors"
                    >
                      Select All
                    </button>
                    <button
                      type="button"
                      phx-click="deselect_all"
                      class="px-3 py-1 text-xs font-medium text-gray-400 hover:text-gray-300 bg-dark-600 hover:bg-dark-500 rounded transition-colors"
                    >
                      Deselect All
                    </button>
                  </div>
                </div>

                <p :if={@form_errors[:congregants]} class="mb-4 text-sm text-red-400">
                  <.icon name="hero-exclamation-circle" class="h-4 w-4 inline mr-1" />
                  {@form_errors[:congregants]}
                </p>

                <%!-- Search - separate from main form to avoid triggering validate --%>
                <div class="mb-4">
                  <div class="relative">
                    <.icon
                      name="hero-magnifying-glass"
                      class="absolute left-3 top-1/2 h-4 w-4 text-gray-500 transform -translate-y-1/2 pointer-events-none"
                    />
                    <input
                      type="text"
                      phx-change="search_congregants"
                      phx-debounce="300"
                      name="query"
                      value={@search_query}
                      placeholder="Search congregants..."
                      class="w-full pl-10 pr-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                    />
                  </div>
                </div>

                <%!-- Congregant List --%>
                <div class="max-h-[500px] overflow-y-auto space-y-1">
                  <div
                    :for={congregant <- @filtered_congregants}
                    phx-click="toggle_congregant"
                    phx-value-id={congregant.id}
                    class={[
                      "flex items-center p-3 rounded-lg cursor-pointer transition-all",
                      MapSet.member?(@selected_congregant_ids, congregant.id) &&
                        "bg-primary-500/20 border border-primary-500/30",
                      !MapSet.member?(@selected_congregant_ids, congregant.id) &&
                        "bg-dark-700/50 border border-transparent hover:bg-dark-700"
                    ]}
                  >
                    <div class={[
                      "flex-shrink-0 w-5 h-5 rounded border-2 mr-3 flex items-center justify-center transition-colors",
                      MapSet.member?(@selected_congregant_ids, congregant.id) &&
                        "bg-primary-500 border-primary-500",
                      !MapSet.member?(@selected_congregant_ids, congregant.id) && "border-dark-500"
                    ]}>
                      <.icon
                        :if={MapSet.member?(@selected_congregant_ids, congregant.id)}
                        name="hero-check"
                        class="h-3 w-3 text-white"
                      />
                    </div>
                    <.avatar
                      image={congregant.image}
                      first_name={congregant.first_name}
                      last_name={congregant.last_name}
                      size="sm"
                    />
                    <div class="ml-3 flex-1 min-w-0">
                      <p class="text-sm font-medium text-white truncate">
                        {congregant.first_name} {congregant.last_name}
                      </p>
                      <p class="text-xs text-gray-500">
                        ID: {congregant.member_id}
                      </p>
                    </div>
                  </div>
                  <div :if={@filtered_congregants == []} class="py-8 text-center text-gray-500">
                    <.icon name="hero-user-group" class="h-8 w-8 mx-auto mb-2 text-gray-600" />
                    <p>No congregants found</p>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Right Column: Headcount Info (only in headcount mode) --%>
            <div :if={@attendance_mode == "headcount"} class="lg:col-span-2">
              <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
                <div class="flex flex-col items-center justify-center py-12 text-center">
                  <div class="w-16 h-16 bg-primary-500/20 rounded-full flex items-center justify-center mb-4">
                    <.icon name="hero-calculator" class="h-8 w-8 text-primary-400" />
                  </div>
                  <h3 class="text-lg font-semibold text-white mb-2">Headcount Mode</h3>
                  <p class="text-gray-400 max-w-sm">
                    Enter the total number of attendees in the left panel.
                    Individual congregant records will not be created.
                  </p>
                  <div class="mt-6 p-4 bg-dark-700/50 rounded-lg">
                    <p class="text-sm text-gray-500">
                      <.icon name="hero-information-circle" class="h-4 w-4 inline mr-1" />
                      Use this mode for services where you only have a headcount
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
