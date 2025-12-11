defmodule ChurchappWeb.DatetimeInput do
  @moduledoc """
  A datetime input component that handles UTC <-> local time conversion.

  The component uses a visible datetime-local input for user interaction (showing local time)
  and a hidden input for form submission (containing UTC ISO string).

  This ensures that:
  1. Users always see and enter times in their local timezone
  2. Times are stored in UTC in the database
  3. Times are displayed correctly when retrieved
  """
  use Phoenix.Component

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :class, :string, default: nil
  attr :max, :string, default: nil
  attr :required, :boolean, default: false

  def datetime_input(assigns) do
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []
    assigns = assign(assigns, :errors, errors)

    ~H"""
    <div class="fieldset mb-2" id={"#{@field.id}-wrapper"} phx-hook="DateTimeInput">
      <label>
        <span :if={@label} class="label mb-1">
          {@label}
          <span :if={@required} class="text-red-500">*</span>
        </span>
        <%!-- Visible input for user interaction (local time) --%>
        <input
          type="datetime-local"
          id={"#{@field.id}-local"}
          data-utc-value={format_utc_value(@field.value)}
          max={@max}
          class={[
            @class || "w-full input",
            @errors != [] && "input-error"
          ]}
        />
        <%!-- Hidden input for form submission (UTC ISO string) --%>
        <input
          type="hidden"
          id={@field.id}
          name={@field.name}
          value={format_utc_value(@field.value)}
        />
      </label>
      <%= for msg <- Enum.map(@errors, &translate_error/1) do %>
        <p class="mt-1.5 flex gap-2 items-center text-sm text-red-400">{msg}</p>
      <% end %>
    </div>
    """
  end

  defp format_utc_value(nil), do: nil
  defp format_utc_value(""), do: nil

  defp format_utc_value(%DateTime{} = dt) do
    DateTime.to_iso8601(dt)
  end

  defp format_utc_value(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_iso8601()
  end

  defp format_utc_value(value) when is_binary(value) do
    # If it's already an ISO string, return as-is
    value
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
