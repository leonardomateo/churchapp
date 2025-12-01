defmodule Chms.Church.Ministries do
  @moduledoc """
  Module for managing church ministries.
  Provides a predefined list of ministries that can be selected for congregants.
  """

  @ministries [
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
    "Trustees",
  ]

  @doc """
  Returns the list of all available ministries.
  """
  def list_ministries, do: @ministries

  @doc """
  Returns a list of tuples suitable for form options.
  Each tuple contains {display_name, value}.
  """
  def ministry_options do
    Enum.map(@ministries, &{&1, &1})
  end

  @doc """
  Checks if a ministry is in the predefined list.
  """
  def valid_ministry?(ministry) when is_binary(ministry) do
    ministry in @ministries
  end

  def valid_ministry?(_), do: false

  @doc """
  Filters a list to only include valid ministries.
  """
  def filter_valid(ministries) when is_list(ministries) do
    Enum.filter(ministries, &valid_ministry?/1)
  end

  def filter_valid(_), do: []
end
