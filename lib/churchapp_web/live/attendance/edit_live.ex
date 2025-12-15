defmodule ChurchappWeb.AttendanceLive.EditLive do
  use ChurchappWeb, :live_view

  require Ash.Query

  def mount(%{"id" => id}, _session, socket) do
    actor = socket.assigns[:current_user]

    case load_session(id, actor) do
      {:ok, session} ->
        # Load categories
        categories =
          case Chms.Church.list_active_attendance_categories(actor: actor) do
            {:ok, cats} -> cats
            _ -> []
          end

        # Load all congregants
        congregants =
          case Chms.Church.list_congregants(actor: actor) do
            {:ok, list} ->
              list
              |> Enum.filter(&(&1.status == :member))
              |> Enum.sort_by(&"#{&1.first_name} #{&1.last_name}")

            _ ->
              []
          end

        # Get selected congregant IDs from existing records
        selected_ids =
          session.records
          |> Enum.filter(& &1.present)
          |> Enum.map(& &1.congregant_id)
          |> MapSet.new()

        # Parse datetime
        session_date = DateTime.to_date(session.session_datetime) |> Date.to_iso8601()

        session_time =
          DateTime.to_time(session.session_datetime) |> Time.to_iso8601() |> String.slice(0, 5)

        # Determine attendance mode based on whether there are individual records
        # If no records but there's a total_present, it's headcount mode
        attendance_mode =
          if length(session.records) == 0 and session.total_present > 0 do
            "headcount"
          else
            "individual"
          end

        manual_count =
          if attendance_mode == "headcount" do
            Integer.to_string(session.total_present)
          else
            ""
          end

        socket =
          socket
          |> assign(:page_title, "Edit Attendance")
          |> assign(:session, session)
          |> assign(:categories, categories)
          |> assign(:congregants, congregants)
          |> assign(:selected_category_id, session.category_id)
          |> assign(:session_date, session_date)
          |> assign(:session_time, session_time)
          |> assign(:notes, session.notes || "")
          |> assign(:selected_congregant_ids, selected_ids)
          |> assign(:attendance_mode, attendance_mode)
          |> assign(:manual_count, manual_count)
          |> assign(:search_query, "")
          |> assign(:form_errors, %{})

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Session not found")
         |> push_navigate(to: ~p"/attendance")}
    end
  end

  defp load_session(id, actor) do
    Chms.Church.AttendanceSessions
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load([:category, records: [:congregant]])
    |> Ash.read_one(actor: actor)
  end

  def handle_event("select_category", %{"category" => category_id}, socket) do
    form_errors = Map.delete(socket.assigns.form_errors, :category)

    {:noreply,
     socket
     |> assign(:selected_category_id, category_id)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("update_date", %{"date" => date}, socket) do
    form_errors = Map.delete(socket.assigns.form_errors, :date)

    {:noreply,
     socket
     |> assign(:session_date, date)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("update_time", %{"time" => time}, socket) do
    form_errors = Map.delete(socket.assigns.form_errors, :time)

    {:noreply,
     socket
     |> assign(:session_time, time)
     |> assign(:form_errors, form_errors)}
  end

  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, :notes, notes)}
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

  def handle_event("update_manual_count", %{"count" => count}, socket) do
    form_errors = Map.delete(socket.assigns.form_errors, :manual_count)

    {:noreply,
     socket
     |> assign(:manual_count, count)
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
    {:noreply, assign(socket, :selected_congregant_ids, new_selected)}
  end

  def handle_event("deselect_all", _params, socket) do
    filtered = filtered_congregants(socket.assigns.congregants, socket.assigns.search_query)
    filtered_ids = filtered |> Enum.map(& &1.id) |> MapSet.new()
    current = socket.assigns.selected_congregant_ids
    new_selected = MapSet.difference(current, filtered_ids)
    {:noreply, assign(socket, :selected_congregant_ids, new_selected)}
  end

  def handle_event("save", _params, socket) do
    errors = validate_form(socket.assigns)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :form_errors, errors)}
    else
      case update_session_with_records(socket) do
        {:ok, session} ->
          {:noreply,
           socket
           |> put_flash(:info, "Attendance updated successfully")
           |> push_navigate(to: ~p"/attendance/#{session.id}")}

        {:error, message} ->
          {:noreply,
           socket
           |> put_flash(:error, message)
           |> assign(:form_errors, %{})}
      end
    end
  end

  defp validate_form(assigns) do
    errors = %{}

    errors =
      if assigns.selected_category_id == "" do
        Map.put(errors, :category, "Please select a category")
      else
        errors
      end

    errors =
      if assigns.session_date == "" do
        Map.put(errors, :date, "Please select a date")
      else
        errors
      end

    errors =
      if assigns.session_time == "" do
        Map.put(errors, :time, "Please select a time")
      else
        errors
      end

    # Mode-specific validation
    errors =
      case assigns.attendance_mode do
        "headcount" ->
          manual_count = assigns.manual_count || ""

          cond do
            manual_count == "" ->
              Map.put(errors, :manual_count, "Please enter the attendance count")

            not valid_positive_integer?(manual_count) ->
              Map.put(errors, :manual_count, "Please enter a valid positive number")

            true ->
              errors
          end

        _ ->
          if MapSet.size(assigns.selected_congregant_ids) == 0 do
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

  defp update_session_with_records(socket) do
    actor = socket.assigns[:current_user]
    session = socket.assigns.session
    mode = socket.assigns.attendance_mode

    # Parse datetime
    datetime =
      case DateTime.new(
             Date.from_iso8601!(socket.assigns.session_date),
             Time.from_iso8601!("#{socket.assigns.session_time}:00"),
             "Etc/UTC"
           ) do
        {:ok, dt} -> dt
        _ -> DateTime.utc_now()
      end

    session_attrs = %{
      category_id: socket.assigns.selected_category_id,
      session_datetime: datetime,
      notes: socket.assigns.notes
    }

    case Chms.Church.update_attendance_session(session, session_attrs, actor: actor) do
      {:ok, updated_session} ->
        # Delete all existing records (for both modes)
        Enum.each(session.records, fn record ->
          Chms.Church.destroy_attendance_record(record, actor: actor)
        end)

        case mode do
          "headcount" ->
            # Headcount mode: just set the total_present directly
            {count, _} = Integer.parse(socket.assigns.manual_count)
            Chms.Church.update_attendance_session_total(updated_session, count, actor: actor)

          _ ->
            # Individual mode: create new records
            selected_ids = MapSet.to_list(socket.assigns.selected_congregant_ids)

            Enum.each(selected_ids, fn congregant_id ->
              record_attrs = %{
                session_id: updated_session.id,
                congregant_id: congregant_id,
                present: true
              }

              Chms.Church.create_attendance_record(record_attrs, actor: actor)
            end)

            # Update the total_present count
            Chms.Church.update_attendance_session_total(updated_session, length(selected_ids),
              actor: actor
            )
        end

        {:ok, updated_session}

      {:error, _changeset} ->
        {:error, "Failed to update attendance session"}
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
          navigate={~p"/attendance/#{@session.id}"}
          class="inline-flex items-center text-sm text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to Session
        </.link>
      </div>

      <div class="max-w-4xl mx-auto">
        <div class="mb-6">
          <h2 class="text-2xl font-bold text-white">Edit Attendance</h2>
          <p class="mt-1 text-sm text-gray-400">
            Update the session details and attendance records
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

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Left Column: Session Details --%>
          <div class="lg:col-span-1 space-y-6">
            <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
              <h3 class="text-lg font-semibold text-white mb-4">Session Details</h3>

              <%!-- Category Selection --%>
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Category <span class="text-red-500">*</span>
                </label>
                <select
                  phx-change="select_category"
                  name="category"
                  class={[
                    "w-full h-10 px-4 text-gray-200 bg-dark-700 border rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent cursor-pointer",
                    @form_errors[:category] && "border-red-500",
                    !@form_errors[:category] && "border-dark-600"
                  ]}
                >
                  <option value="" selected={@selected_category_id == ""}>Select a category...</option>
                  <option :for={category <- @categories} value={category.id} selected={@selected_category_id == category.id}>
                    {category.name}
                  </option>
                </select>
                <p :if={@form_errors[:category]} class="mt-1 text-sm text-red-400">
                  {@form_errors[:category]}
                </p>
              </div>

              <%!-- Date Selection --%>
              <div class="mb-4">
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Date <span class="text-red-500">*</span>
                </label>
                <input
                  type="date"
                  phx-change="update_date"
                  name="date"
                  value={@session_date}
                  phx-hook="DatePickerClose"
                  id="session-date"
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
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Time <span class="text-red-500">*</span>
                </label>
                <input
                  type="time"
                  phx-change="update_time"
                  name="time"
                  value={@session_time}
                  phx-hook="DatePickerClose"
                  id="session-time"
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
                <label class="block text-sm font-medium text-gray-300 mb-2">
                  Notes
                </label>
                <textarea
                  phx-change="update_notes"
                  name="notes"
                  rows="3"
                  placeholder="Optional session notes..."
                  class="w-full px-4 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent resize-none"
                >{@notes}</textarea>
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
                  phx-change="update_manual_count"
                  name="count"
                  min="1"
                  value={@manual_count}
                  placeholder="Enter total count..."
                  class={[
                    "w-full pl-4 pr-10 py-2 text-gray-200 placeholder-gray-500 bg-dark-700 border rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent",
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
                      <%= if @manual_count != "", do: @manual_count, else: "0" %>
                    <% else %>
                      {MapSet.size(@selected_congregant_ids)}
                    <% end %>
                  </span>
                </div>
                <div :if={@attendance_mode == "individual"} class="flex justify-between items-center text-sm">
                  <span class="text-gray-500">Previously recorded</span>
                  <span class="text-gray-400">{length(@session.records)}</span>
                </div>
              </div>
              <button
                type="button"
                phx-click="save"
                class="w-full mt-6 px-4 py-3 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
              >
                <.icon name="hero-check" class="mr-2 h-4 w-4 inline" /> Save Changes
              </button>
            </div>
          </div>

          <%!-- Right Column: Congregant Selection (only in individual mode) --%>
          <div :if={@attendance_mode == "individual"} class="lg:col-span-2">
            <div class="bg-dark-800 rounded-lg border border-dark-700 p-6">
              <div class="mb-4">
                <h3 class="text-lg font-semibold text-white">
                  Mark Present <span class="text-red-500">*</span>
                </h3>
              </div>

              <p :if={@form_errors[:congregants]} class="mb-4 text-sm text-red-400">
                <.icon name="hero-exclamation-circle" class="h-4 w-4 inline mr-1" />
                {@form_errors[:congregants]}
              </p>

              <%!-- Search --%>
              <div class="mb-4">
                <form phx-change="search_congregants" class="relative">
                  <.icon
                    name="hero-magnifying-glass"
                    class="absolute left-4 top-1/2 h-4 w-4 text-gray-500 transform -translate-y-1/2 pointer-events-none z-10"
                  />
                  <input
                    type="text"
                    name="query"
                    value={@search_query}
                    placeholder="Search congregants..."
                    style="padding-left: 2.75rem;"
                    class="w-full py-2 pr-4 text-gray-200 placeholder-gray-500 bg-dark-700 border border-dark-600 rounded-md focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                  />
                </form>
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
      </div>
    </div>
    """
  end
end
