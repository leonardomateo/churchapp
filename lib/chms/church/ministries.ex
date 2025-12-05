defmodule Chms.Church.Ministries do
  @moduledoc """
  Module for managing church ministries.
  Provides a predefined list of ministries combined with custom ministries from the database.
  Similar to ContributionTypes, allows dynamic ministry creation through the web interface.
  """

  @default_ministries [
    "Worship",
    "Royal Rangers",
    "Evangelism",
    "Women",
    "Men",
    "Girls",
    "Children",
    "Pro-Presenter",
    "Dance",
    "Missions",
    "Pastor",
    "Pastor's Wife",
    "Media",
    "Sound",
    "Kitchen",
    "Properties-admin",
    "Education",
    "Deacon",
    "Deaconess",
    "Ushers",
    "Youth",
    "General Secretary",
    "Trustees"
  ]

  @doc """
  Returns the list of default ministries.
  """
  def default_ministries, do: @default_ministries

  @doc """
  Returns the list of all available ministries (default + custom from database).
  """
  def list_ministries, do: all_ministries()

  @doc """
  Get all unique ministry names from the database combined with defaults.
  This allows for dynamic ministries that users have entered.
  """
  def all_ministries do
    # Get unique ministry names from database
    custom_ministries =
      try do
        Chms.Church.MinistryFunds
        |> Ash.Query.select([:ministry_name])
        |> Ash.read!()
        |> Enum.map(& &1.ministry_name)
        |> Enum.uniq()
      rescue
        _ -> []
      end

    # Combine with defaults and remove duplicates
    (@default_ministries ++ custom_ministries)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Returns a list of tuples suitable for form options.
  Each tuple contains {display_name, value}.
  """
  def ministry_options do
    all_ministries()
    |> Enum.map(&{&1, &1})
  end

  @doc """
  Checks if a ministry is in the predefined list.
  """
  def valid_ministry?(ministry) when is_binary(ministry) do
    ministry in @default_ministries
  end

  def valid_ministry?(_), do: false

  @doc """
  Filters a list to only include valid ministries from the default list.
  """
  def filter_valid(ministries) when is_list(ministries) do
    Enum.filter(ministries, &valid_ministry?/1)
  end

  def filter_valid(_), do: []
end
