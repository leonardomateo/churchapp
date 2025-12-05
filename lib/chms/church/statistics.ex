defmodule Chms.Church.Statistics do
  @moduledoc """
  Context module for aggregating and computing statistics for congregants and contributions.
  """

  require Ash.Query

  @doc """
  Gets count of congregants grouped by status.
  Returns a list of maps with label and value keys.
  """
  def get_congregant_counts_by_status(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        counts =
          congregants
          |> Enum.group_by(& &1.status)
          |> Enum.map(fn {status, list} ->
            %{
              label: format_status(status),
              value: length(list)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, counts}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of congregants grouped by country.
  Returns a list of maps with label and value keys, limited to top 10.
  """
  def get_congregant_counts_by_country(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        counts =
          congregants
          |> Enum.reject(&is_nil(&1.country))
          |> Enum.group_by(& &1.country)
          |> Enum.map(fn {country, list} ->
            %{
              label: country || "Unknown",
              value: length(list)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)
          |> Enum.take(10)

        {:ok, counts}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets total count of all congregants.
  """
  def get_total_congregants(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        {:ok, length(congregants)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of active members (status: member).
  """
  def get_active_members_count(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(status == :member)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        {:ok, length(congregants)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of visitors (status: visitor).
  """
  def get_visitors_count(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(status == :visitor)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        {:ok, length(congregants)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of honorific members (status: honorific).
  """
  def get_honorific_count(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(status == :honorific)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        {:ok, length(congregants)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of deceased members (status: deceased).
  """
  def get_deceased_count(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(status == :deceased)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        {:ok, length(congregants)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of congregants grouped by contribution type.
  Returns a list of maps with label and value keys.
  """
  def get_contribution_counts_by_type(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        counts =
          contributions
          |> Enum.group_by(& &1.contribution_type)
          |> Enum.map(fn {type, list} ->
            %{
              label: type,
              value: length(list)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, counts}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets total revenue from all contributions.
  """
  def get_total_revenue(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        total =
          contributions
          |> Enum.map(& &1.revenue)
          |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

        {:ok, total}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets total revenue grouped by contribution type.
  Returns a list of maps with label and value keys.
  """
  def get_revenue_by_type(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        revenue_by_type =
          contributions
          |> Enum.group_by(& &1.contribution_type)
          |> Enum.map(fn {type, list} ->
            total =
              list
              |> Enum.map(& &1.revenue)
              |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

            %{
              label: type,
              value: Decimal.to_float(total)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, revenue_by_type}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets total count of all contributions.
  """
  def get_total_contributions(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        {:ok, length(contributions)}

      {:error, error} ->
        {:error, error}
    end
  end

  # Private helper functions

  defp format_status(:member), do: "Member"
  defp format_status(:visitor), do: "Visitor"
  defp format_status(:honorific), do: "Honorific"
  defp format_status(:deceased), do: "Deceased"
  defp format_status(status), do: status |> to_string() |> String.capitalize()
end
