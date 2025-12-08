defmodule Chms.Church.IcalExport do
  @moduledoc """
  Generates iCalendar (.ics) files for church events.

  Follows the iCalendar specification (RFC 5545) for compatibility with
  Google Calendar, Apple Calendar, Outlook, and other calendar applications.
  """

  alias Chms.Church.Events

  @doc """
  Generates an iCalendar string for a list of events.
  """
  def generate_ical(events) when is_list(events) do
    """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//PACHMS//Event Calendar//EN
    CALSCALE:GREGORIAN
    METHOD:PUBLISH
    X-WR-CALNAME:PACHMS Church Events
    #{Enum.map_join(events, "\n", &event_to_vevent/1)}
    END:VCALENDAR
    """
    |> String.trim()
  end

  @doc """
  Generates an iCalendar string for a single event.
  """
  def generate_ical_single(event) do
    generate_ical([event])
  end

  defp event_to_vevent(event) do
    uid = "#{event.id}@pachms.church"
    dtstamp = format_datetime(DateTime.utc_now())
    dtstart = format_event_datetime(event.start_time, event.all_day)
    dtend = format_event_datetime(event.end_time, event.all_day)
    summary = escape_text(event.title)
    description = escape_text(event.description || "")
    location = escape_text(event.location || "")

    color_name = color_to_name(event.color || Events.default_color_for_type(event.event_type))

    vevent = """
    BEGIN:VEVENT
    UID:#{uid}
    DTSTAMP:#{dtstamp}
    #{dtstart_line(dtstart, event.all_day)}
    #{dtend_line(dtend, event.all_day)}
    SUMMARY:#{summary}
    """

    vevent = if description != "", do: vevent <> "DESCRIPTION:#{description}\n", else: vevent
    vevent = if location != "", do: vevent <> "LOCATION:#{location}\n", else: vevent
    vevent = vevent <> "CATEGORIES:#{event_type_category(event.event_type)}\n"
    vevent = vevent <> "COLOR:#{color_name}\n"

    # Add recurrence rule if recurring
    vevent =
      if event.is_recurring && event.recurrence_rule do
        rrule = format_rrule(event.recurrence_rule, event.recurrence_end_date)
        vevent <> "RRULE:#{rrule}\n"
      else
        vevent
      end

    vevent <> "END:VEVENT"
  end

  defp dtstart_line(datetime, true), do: "DTSTART;VALUE=DATE:#{datetime}"
  defp dtstart_line(datetime, false), do: "DTSTART:#{datetime}"

  defp dtend_line(datetime, true), do: "DTEND;VALUE=DATE:#{datetime}"
  defp dtend_line(datetime, false), do: "DTEND:#{datetime}"

  defp format_datetime(%DateTime{} = dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601(:basic)
    |> String.replace("-", "")
    |> String.replace(":", "")
    |> Kernel.<>("Z")
  end

  defp format_event_datetime(%DateTime{} = dt, true) do
    # For all-day events, just use the date
    dt
    |> DateTime.to_date()
    |> Date.to_iso8601(:basic)
    |> String.replace("-", "")
  end

  defp format_event_datetime(%DateTime{} = dt, false) do
    format_datetime(dt)
  end

  defp escape_text(nil), do: ""

  defp escape_text(text) do
    text
    |> String.replace("\\", "\\\\")
    |> String.replace(",", "\\,")
    |> String.replace(";", "\\;")
    |> String.replace("\n", "\\n")
  end

  defp event_type_category(:service), do: "CHURCH SERVICE"
  defp event_type_category(:midweek_service), do: "MIDWEEK SERVICE"
  defp event_type_category(:special_service), do: "SPECIAL SERVICE"
  defp event_type_category(_), do: "CHURCH EVENT"

  defp color_to_name("#06b6d4"), do: "cyan"
  defp color_to_name("#8b5cf6"), do: "purple"
  defp color_to_name("#f59e0b"), do: "yellow"
  defp color_to_name(_), do: "cyan"

  defp format_rrule(rrule, nil), do: rrule

  defp format_rrule(rrule, end_date) do
    # Add UNTIL clause if end date is specified and not already in the rule
    if String.contains?(rrule, "UNTIL") do
      rrule
    else
      until = end_date |> Date.to_iso8601(:basic) |> String.replace("-", "")
      "#{rrule};UNTIL=#{until}T235959Z"
    end
  end
end
