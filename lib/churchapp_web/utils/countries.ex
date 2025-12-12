defmodule ChurchappWeb.Utils.Countries do
  @moduledoc """
  Contains countries data for use in forms and dropdowns.
  Provides a comprehensive list of world countries with ISO codes.
  """

  @default_countries [
    # North America
    {"United States", "US"},
    {"Canada", "CA"},
    {"Mexico", "MX"},
    # Europe
    {"United Kingdom", "GB"},
    {"Germany", "DE"},
    {"France", "FR"},
    {"Italy", "IT"},
    {"Spain", "ES"},
    {"Portugal", "PT"},
    {"Netherlands", "NL"},
    {"Belgium", "BE"},
    {"Switzerland", "CH"},
    {"Austria", "AT"},
    {"Sweden", "SE"},
    {"Norway", "NO"},
    {"Denmark", "DK"},
    {"Finland", "FI"},
    {"Ireland", "IE"},
    {"Poland", "PL"},
    {"Greece", "GR"},
    # Oceania
    {"Australia", "AU"},
    {"New Zealand", "NZ"},
    # Asia
    {"Japan", "JP"},
    {"China", "CN"},
    {"South Korea", "KR"},
    {"India", "IN"},
    {"Philippines", "PH"},
    {"Vietnam", "VN"},
    {"Thailand", "TH"},
    {"Indonesia", "ID"},
    {"Malaysia", "MY"},
    {"Singapore", "SG"},
    # South America (all Spanish-speaking + Brazil)
    {"Brazil", "BR"},
    {"Argentina", "AR"},
    {"Bolivia", "BO"},
    {"Chile", "CL"},
    {"Colombia", "CO"},
    {"Ecuador", "EC"},
    {"Paraguay", "PY"},
    {"Peru", "PE"},
    {"Uruguay", "UY"},
    {"Venezuela", "VE"},
    # Central America (all Spanish-speaking)
    {"Guatemala", "GT"},
    {"Honduras", "HN"},
    {"El Salvador", "SV"},
    {"Nicaragua", "NI"},
    {"Costa Rica", "CR"},
    {"Panama", "PA"},
    {"Belize", "BZ"},
    # Caribbean
    {"Cuba", "CU"},
    {"Dominican Republic", "DO"},
    {"Puerto Rico", "PR"},
    {"Jamaica", "JM"},
    {"Haiti", "HT"},
    {"Trinidad and Tobago", "TT"},
    {"Barbados", "BB"},
    {"Bahamas", "BS"},
    # Africa
    {"South Africa", "ZA"},
    {"Nigeria", "NG"},
    {"Kenya", "KE"},
    {"Ghana", "GH"},
    {"Egypt", "EG"},
    {"Morocco", "MA"},
    {"Ethiopia", "ET"},
    {"Tanzania", "TZ"},
    {"Uganda", "UG"},
    {"Zimbabwe", "ZW"},
    {"Equatorial Guinea", "GQ"},
    # Middle East
    {"Israel", "IL"},
    {"United Arab Emirates", "AE"},
    {"Saudi Arabia", "SA"},
    {"Turkey", "TR"},
    # Eastern Europe
    {"Russia", "RU"},
    {"Ukraine", "UA"}
  ]

  def default_countries do
    @default_countries
  end

  def get_country_by_code(code) when is_binary(code) do
    code_upper = String.upcase(code)
    Enum.find(@default_countries, fn {_name, c} -> c == code_upper end)
  end

  def get_country_by_name(name) when is_binary(name) do
    name_lower = String.downcase(name)

    Enum.find(@default_countries, fn {country_name, _code} ->
      String.downcase(country_name) == name_lower
    end)
  end

  def search_countries(countries, query) when is_binary(query) do
    if query == "" do
      countries
    else
      query_lower = String.downcase(query)

      Enum.filter(countries, fn {name, code} ->
        String.contains?(String.downcase(name), query_lower) or
          String.contains?(String.downcase(code), query_lower)
      end)
    end
  end

  @doc """
  Formats a list of countries for display in a selector.
  Returns tuples of {display_name, value}.
  """
  def country_options(additional_countries \\ []) do
    all_countries = @default_countries ++ additional_countries
    # Sort alphabetically by name and remove duplicates
    all_countries
    |> Enum.uniq_by(fn {name, _code} -> String.downcase(name) end)
    |> Enum.sort_by(fn {name, _code} -> String.downcase(name) end)
  end
end
