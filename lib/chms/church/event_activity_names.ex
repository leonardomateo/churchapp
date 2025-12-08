defmodule Chms.Church.EventActivityNames do
  @moduledoc """
  Module for managing event/activity names.
  Fetches unique event titles from existing events - no default values.
  """

  @doc """
  Get all unique event titles from the database.
  Returns an empty list if no events exist.
  """
  def all_names do
    try do
      Chms.Church.Events
      |> Ash.Query.select([:title])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.title)
      |> Enum.uniq()
      |> Enum.sort()
    rescue
      _ -> []
    end
  end

  @doc """
  Returns all names as form options.
  Each tuple contains {display_name, value}.
  """
  def all_name_options do
    all_names()
    |> Enum.map(&{&1, &1})
  end
end
