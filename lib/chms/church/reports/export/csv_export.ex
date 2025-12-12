defmodule Chms.Church.Reports.Export.CsvExport do
  @moduledoc """
  Generates CSV files from report results.
  """

  @doc """
  Generate a CSV file from report results.
  Returns a string containing the CSV data.
  """
  def generate(resource_config, results) do
    # Get exportable fields only
    exportable_fields = Enum.filter(resource_config.fields, & &1.exportable)

    # Generate header row
    header_row =
      exportable_fields
      |> Enum.map(& &1.label)
      |> Enum.map_join(",", &escape_csv_value/1)

    # Generate data rows
    data_rows =
      results
      |> Enum.map(fn result ->
        exportable_fields
        |> Enum.map(&get_field_value(result, &1))
        |> Enum.map(&format_value(&1, &1))
        |> Enum.map_join(",", &escape_csv_value/1)
      end)
      |> Enum.join("\n")

    # Combine header and data
    if data_rows == "" do
      header_row
    else
      "#{header_row}\n#{data_rows}"
    end
  end

  # Get field value from result
  defp get_field_value(result, field) do
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

  # Format value based on type
  defp format_value(nil, _field), do: ""
  defp format_value("", _field), do: ""

  defp format_value(value, %{type: :currency}) do
    Decimal.to_string(value, :normal)
  end

  defp format_value(value, %{type: :datetime}) do
    Calendar.strftime(value, "%Y-%m-%d %H:%M:%S")
  end

  defp format_value(value, %{type: :date}) do
    Date.to_string(value)
  end

  defp format_value(value, %{type: :boolean}) do
    if value, do: "Yes", else: "No"
  end

  defp format_value(value, %{type: :array}) when is_list(value) do
    Enum.join(value, "; ")
  end

  defp format_value(value, %{type: :atom}) when is_atom(value) do
    value
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  defp format_value(value, _field), do: to_string(value)

  # Escape CSV value (handle quotes, commas, newlines)
  defp escape_csv_value(value) when is_binary(value) do
    value_str = to_string(value)

    # If value contains comma, quote, or newline, wrap in quotes and escape internal quotes
    if String.contains?(value_str, [",", "\"", "\n"]) do
      escaped = String.replace(value_str, "\"", "\"\"")
      "\"#{escaped}\""
    else
      value_str
    end
  end

  defp escape_csv_value(value), do: escape_csv_value(to_string(value))
end
