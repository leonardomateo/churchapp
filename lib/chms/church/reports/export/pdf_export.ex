defmodule Chms.Church.Reports.Export.PdfExport do
  @moduledoc """
  Generates PDF files from report results.
  Uses pdf_generator library which requires wkhtmltopdf to be installed on the system.

  If wkhtmltopdf is not available, the module will fall back to generating
  print-ready HTML that can be printed to PDF via the browser.
  """

  @doc """
  Generate a PDF file from report results.
  Returns {:ok, binary} with the PDF content or {:error, reason}.

  Note: This requires wkhtmltopdf to be installed on the system.
  If not available, use generate_html/3 and the browser print-to-PDF feature.
  """
  def generate(resource_config, results, filter_params \\ %{}) do
    html = build_html_template(resource_config, results, filter_params)

    # Use apply/3 to avoid compile-time warnings when wkhtmltopdf is not installed
    try do
      case apply(PdfGenerator, :generate_binary, [
             html,
             [page_size: "A4", shell_params: ["--orientation", "Landscape"]]
           ]) do
        {:ok, pdf_binary} ->
          {:ok, pdf_binary}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      _ -> {:error, :pdf_generator_not_available}
    end
  end

  @doc """
  Generate HTML content suitable for printing or PDF export via browser.
  This is a fallback when wkhtmltopdf is not available.
  """
  def generate_html(resource_config, results, filter_params \\ %{}) do
    build_html_template(resource_config, results, filter_params)
  end

  # Build the complete HTML template for the PDF
  defp build_html_template(resource_config, results, filter_params) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>#{resource_config.name} Report</title>
      <style>
        #{pdf_styles()}
      </style>
    </head>
    <body>
      #{format_header(resource_config)}
      #{format_filter_summary(resource_config, filter_params)}
      #{format_table(resource_config, results)}
      #{format_footer()}
    </body>
    </html>
    """
  end

  # CSS styles for the PDF
  defp pdf_styles do
    """
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: 'Helvetica Neue', Arial, sans-serif;
      font-size: 10pt;
      color: #333;
      line-height: 1.4;
      padding: 20px;
      background: #fff;
    }

    .header {
      text-align: center;
      margin-bottom: 20px;
      padding-bottom: 15px;
      border-bottom: 2px solid #06b6d4;
    }

    .header h1 {
      font-size: 18pt;
      color: #1a1a1a;
      margin-bottom: 5px;
      font-weight: 600;
    }

    .header .subtitle {
      font-size: 10pt;
      color: #666;
    }

    .header .date {
      font-size: 9pt;
      color: #888;
      margin-top: 5px;
    }

    .filter-summary {
      background: #f8f9fa;
      border: 1px solid #e9ecef;
      border-radius: 4px;
      padding: 10px 15px;
      margin-bottom: 20px;
      font-size: 9pt;
    }

    .filter-summary h3 {
      font-size: 10pt;
      color: #495057;
      margin-bottom: 8px;
      font-weight: 600;
    }

    .filter-summary .filters {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
    }

    .filter-summary .filter-item {
      background: #fff;
      border: 1px solid #dee2e6;
      border-radius: 3px;
      padding: 4px 8px;
    }

    .filter-summary .filter-label {
      font-weight: 600;
      color: #495057;
    }

    .filter-summary .filter-value {
      color: #06b6d4;
    }

    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 20px;
      font-size: 9pt;
    }

    thead {
      display: table-header-group;
    }

    th {
      background: #06b6d4;
      color: #fff;
      font-weight: 600;
      text-align: left;
      padding: 10px 8px;
      border: 1px solid #0891b2;
      white-space: nowrap;
    }

    td {
      padding: 8px;
      border: 1px solid #dee2e6;
      vertical-align: top;
    }

    tr:nth-child(even) {
      background: #f8f9fa;
    }

    tr:nth-child(odd) {
      background: #fff;
    }

    .footer {
      margin-top: 20px;
      padding-top: 15px;
      border-top: 1px solid #dee2e6;
      font-size: 8pt;
      color: #888;
      text-align: center;
    }

    .footer .generated {
      margin-bottom: 5px;
    }

    .total-count {
      font-size: 9pt;
      color: #495057;
      margin-bottom: 10px;
    }

    @media print {
      body {
        padding: 0;
      }

      thead {
        display: table-header-group;
      }

      tr {
        page-break-inside: avoid;
      }

      .header {
        page-break-after: avoid;
      }
    }

    @page {
      size: A4 landscape;
      margin: 15mm;
    }
    """
  end

  # Format the report header
  defp format_header(resource_config) do
    """
    <div class="header">
      <h1>#{resource_config.name} Report</h1>
      <div class="subtitle">Church Management System</div>
      <div class="date">Generated on #{format_current_date()}</div>
    </div>
    """
  end

  # Format the filter summary section
  defp format_filter_summary(resource_config, filter_params) do
    active_filters =
      filter_params
      |> Enum.filter(fn {_key, value} -> value && value != "" end)
      |> Enum.map(fn {key, value} ->
        filter_config = Enum.find(resource_config.filters, &(to_string(&1.key) == key))
        label = if filter_config, do: filter_config.label, else: String.capitalize(key)
        {label, format_filter_value(value)}
      end)

    if Enum.empty?(active_filters) do
      ""
    else
      filter_items =
        active_filters
        |> Enum.map(fn {label, value} ->
          """
          <span class="filter-item">
            <span class="filter-label">#{html_escape(label)}:</span>
            <span class="filter-value">#{html_escape(value)}</span>
          </span>
          """
        end)
        |> Enum.join("\n")

      """
      <div class="filter-summary">
        <h3>Applied Filters</h3>
        <div class="filters">
          #{filter_items}
        </div>
      </div>
      """
    end
  end

  # Format the data table
  defp format_table(resource_config, results) do
    exportable_fields = Enum.filter(resource_config.fields, & &1.exportable)

    header_cells =
      exportable_fields
      |> Enum.map(&"<th>#{html_escape(&1.label)}</th>")
      |> Enum.join("\n")

    body_rows =
      results
      |> Enum.map(fn result ->
        cells =
          exportable_fields
          |> Enum.map(fn field ->
            value = get_field_value(result, field)
            formatted = format_value(value, field)
            "<td>#{html_escape(formatted)}</td>"
          end)
          |> Enum.join("\n")

        "<tr>#{cells}</tr>"
      end)
      |> Enum.join("\n")

    """
    <div class="total-count">Total Records: #{length(results)}</div>
    <table>
      <thead>
        <tr>
          #{header_cells}
        </tr>
      </thead>
      <tbody>
        #{body_rows}
      </tbody>
    </table>
    """
  end

  # Format the report footer
  defp format_footer do
    """
    <div class="footer">
      <div class="generated">Generated by Church Management System</div>
      <div>#{format_current_datetime()}</div>
    </div>
    """
  end

  # Get field value from result (handles computed fields)
  defp get_field_value(result, field) do
    case field do
      %{computed: true, key: :congregant_name} ->
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
    "$#{Decimal.to_string(value, :normal)}"
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

  # Format filter value for display
  defp format_filter_value(value) when is_binary(value), do: value
  defp format_filter_value(value) when is_atom(value), do: to_string(value) |> String.capitalize()
  defp format_filter_value(value), do: to_string(value)

  # HTML escape helper
  defp html_escape(nil), do: ""

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp html_escape(text), do: html_escape(to_string(text))

  # Format current date
  defp format_current_date do
    Date.utc_today() |> Date.to_string()
  end

  # Format current datetime
  defp format_current_datetime do
    DateTime.utc_now()
    |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")
  end
end
