defmodule ChurchappWeb.Utils.USStates do
  @moduledoc """
  Contains US states data for use in forms and dropdowns.
  """

  def states do
    [
      {"Alabama", "AL"},
      {"Alaska", "AK"},
      {"Arizona", "AZ"},
      {"Arkansas", "AR"},
      {"California", "CA"},
      {"Colorado", "CO"},
      {"Connecticut", "CT"},
      {"Delaware", "DE"},
      {"Florida", "FL"},
      {"Georgia", "GA"},
      {"Hawaii", "HI"},
      {"Idaho", "ID"},
      {"Illinois", "IL"},
      {"Indiana", "IN"},
      {"Iowa", "IA"},
      {"Kansas", "KS"},
      {"Kentucky", "KY"},
      {"Louisiana", "LA"},
      {"Maine", "ME"},
      {"Maryland", "MD"},
      {"Massachusetts", "MA"},
      {"Michigan", "MI"},
      {"Minnesota", "MN"},
      {"Mississippi", "MS"},
      {"Missouri", "MO"},
      {"Montana", "MT"},
      {"Nebraska", "NE"},
      {"Nevada", "NV"},
      {"New Hampshire", "NH"},
      {"New Jersey", "NJ"},
      {"New Mexico", "NM"},
      {"New York", "NY"},
      {"North Carolina", "NC"},
      {"North Dakota", "ND"},
      {"Ohio", "OH"},
      {"Oklahoma", "OK"},
      {"Oregon", "OR"},
      {"Pennsylvania", "PA"},
      {"Rhode Island", "RI"},
      {"South Carolina", "SC"},
      {"South Dakota", "SD"},
      {"Tennessee", "TN"},
      {"Texas", "TX"},
      {"Utah", "UT"},
      {"Vermont", "VT"},
      {"Virginia", "VA"},
      {"Washington", "WA"},
      {"West Virginia", "WV"},
      {"Wisconsin", "WI"},
      {"Wyoming", "WY"}
    ]
  end

  def get_state_by_abbr(abbr) when is_binary(abbr) do
    Enum.find(states(), fn {_name, code} -> code == abbr end)
  end

  def get_state_by_name(name) when is_binary(name) do
    Enum.find(states(), fn {state_name, _code} -> state_name == name end)
  end

  def search_states(query) when is_binary(query) do
    query = String.downcase(query)

    states()
    |> Enum.filter(fn {name, code} ->
      String.contains?(String.downcase(name), query) or
      String.contains?(String.downcase(code), query)
    end)
  end
end
