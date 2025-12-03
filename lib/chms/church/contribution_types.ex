defmodule Chms.Church.ContributionTypes do
  @moduledoc """
  Module for managing contribution types.
  Provides predefined contribution types and allows custom entries.
  """

  @default_types [
    "Tithes",
    "General Offering",
    "Mission"
  ]

  @doc """
  Returns the list of default contribution types.
  """
  def default_types, do: @default_types

  @doc """
  Returns a list of tuples suitable for form options.
  Each tuple contains {display_name, value}.
  """
  def contribution_type_options do
    Enum.map(@default_types, &{&1, &1})
  end

  @doc """
  Get all unique contribution types from the database combined with defaults.
  This allows for dynamic types that users have entered.
  """
  def all_types do
    # Get unique contribution types from database
    custom_types =
      try do
        Chms.Church.Contributions
        |> Ash.Query.select([:contribution_type])
        |> Ash.read!()
        |> Enum.map(& &1.contribution_type)
        |> Enum.uniq()
      rescue
        _ -> []
      end

    # Combine with defaults and remove duplicates
    (@default_types ++ custom_types)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns all types as form options.
  """
  def all_type_options do
    all_types()
    |> Enum.map(&{&1, &1})
  end
end
