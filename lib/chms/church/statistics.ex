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
  Returns a list of maps with label and value keys, sorted by count descending.
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
  Gets count of visitors (status: visitor) for the current month.
  """
  def get_visitors_count(actor) do
    query =
      Chms.Church.Congregants
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, congregants} ->
        # Filter for visitors who became members this month
        current_month_start = Date.beginning_of_month(Date.utc_today())

        count =
          congregants
          |> Enum.filter(fn c ->
            c.status == :visitor and
            c.member_since != nil and
            Date.compare(c.member_since, current_month_start) != :lt
          end)
          |> length()

        {:ok, count}

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
  Gets count of contributions grouped by contribution type for the current month.
  Returns a list of maps with label and value keys.
  """
  def get_contribution_counts_by_type(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        # Filter for current month contributions
        current_month_start = Date.beginning_of_month(Date.utc_today())
        current_month_end = Date.end_of_month(Date.utc_today())

        counts =
          contributions
          |> Enum.filter(fn c ->
            contribution_date = DateTime.to_date(c.contribution_date)
            Date.compare(contribution_date, current_month_start) != :lt and
            Date.compare(contribution_date, current_month_end) != :gt
          end)
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
  Gets total revenue from contributions for the current month.
  """
  def get_total_revenue(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        # Filter for current month contributions
        current_month_start = Date.beginning_of_month(Date.utc_today())
        current_month_end = Date.end_of_month(Date.utc_today())

        total =
          contributions
          |> Enum.filter(fn c ->
            contribution_date = DateTime.to_date(c.contribution_date)
            Date.compare(contribution_date, current_month_start) != :lt and
            Date.compare(contribution_date, current_month_end) != :gt
          end)
          |> Enum.map(& &1.revenue)
          |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

        {:ok, total}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets total revenue grouped by contribution type for the current month.
  Returns a list of maps with label and value keys.
  """
  def get_revenue_by_type(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        # Filter for current month contributions
        current_month_start = Date.beginning_of_month(Date.utc_today())
        current_month_end = Date.end_of_month(Date.utc_today())

        revenue_by_type =
          contributions
          |> Enum.filter(fn c ->
            contribution_date = DateTime.to_date(c.contribution_date)
            Date.compare(contribution_date, current_month_start) != :lt and
            Date.compare(contribution_date, current_month_end) != :gt
          end)
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
  Gets total count of contributions for the current month.
  """
  def get_total_contributions(actor) do
    query =
      Chms.Church.Contributions
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, contributions} ->
        # Filter for current month contributions
        current_month_start = Date.beginning_of_month(Date.utc_today())
        current_month_end = Date.end_of_month(Date.utc_today())

        count =
          contributions
          |> Enum.filter(fn c ->
            contribution_date = DateTime.to_date(c.contribution_date)
            Date.compare(contribution_date, current_month_start) != :lt and
            Date.compare(contribution_date, current_month_end) != :gt
          end)
          |> length()

        {:ok, count}

      {:error, error} ->
        {:error, error}
    end
  end

  # Ministry Funds Statistics

  @doc """
  Gets total revenue from ministry funds (revenue transactions).
  Returns the sum of all revenue transactions.
  """
  def get_total_ministry_revenue(actor) do
    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(transaction_type == :revenue)

    case Ash.read(query, actor: actor) do
      {:ok, funds} ->
        total =
          funds
          |> Enum.map(& &1.amount)
          |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

        {:ok, total}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets total expenses from ministry funds (expense transactions).
  Returns the sum of all expense transactions.
  """
  def get_total_ministry_expenses(actor) do
    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(transaction_type == :expense)

    case Ash.read(query, actor: actor) do
      {:ok, funds} ->
        total =
          funds
          |> Enum.map(& &1.amount)
          |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

        {:ok, total}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets the net balance for ministry funds (revenue - expenses).
  Returns the difference between total revenue and total expenses.
  """
  def get_ministry_net_balance(actor) do
    with {:ok, revenue} <- get_total_ministry_revenue(actor),
         {:ok, expenses} <- get_total_ministry_expenses(actor) do
      net = Decimal.sub(revenue, expenses)
      {:ok, net}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Gets ministry funds summary grouped by ministry name.
  Returns a list of maps with ministry name, revenue, expenses, and balance.
  """
  def get_ministry_funds_by_ministry(actor) do
    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, funds} ->
        summary =
          funds
          |> Enum.group_by(& &1.ministry_name)
          |> Enum.map(fn {ministry_name, transactions} ->
            revenue =
              transactions
              |> Enum.filter(&(&1.transaction_type == :revenue))
              |> Enum.map(& &1.amount)
              |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

            expenses =
              transactions
              |> Enum.filter(&(&1.transaction_type == :expense))
              |> Enum.map(& &1.amount)
              |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

            balance = Decimal.sub(revenue, expenses)

            %{
              label: ministry_name,
              revenue: Decimal.to_float(revenue),
              expenses: Decimal.to_float(expenses),
              balance: Decimal.to_float(balance)
            }
          end)
          |> Enum.sort_by(& &1.balance, :desc)

        {:ok, summary}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets count of ministry fund transactions for the current month.
  """
  def get_ministry_transaction_count(actor) do
    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, funds} ->
        # Filter for current month transactions
        current_month_start = Date.beginning_of_month(Date.utc_today())
        current_month_end = Date.end_of_month(Date.utc_today())

        count =
          funds
          |> Enum.filter(fn f ->
            transaction_date = DateTime.to_date(f.transaction_date)
            Date.compare(transaction_date, current_month_start) != :lt and
            Date.compare(transaction_date, current_month_end) != :gt
          end)
          |> length()

        {:ok, count}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets revenue and expenses grouped by ministry for the current month.
  Returns a list of maps with label and value keys for chart display.
  """
  def get_ministry_revenue_chart_data(actor) do
    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(transaction_type == :revenue)

    case Ash.read(query, actor: actor) do
      {:ok, funds} ->
        # Filter for current month transactions
        current_month_start = Date.beginning_of_month(Date.utc_today())
        current_month_end = Date.end_of_month(Date.utc_today())

        revenue_by_ministry =
          funds
          |> Enum.filter(fn f ->
            transaction_date = DateTime.to_date(f.transaction_date)
            Date.compare(transaction_date, current_month_start) != :lt and
            Date.compare(transaction_date, current_month_end) != :gt
          end)
          |> Enum.group_by(& &1.ministry_name)
          |> Enum.map(fn {ministry, list} ->
            total =
              list
              |> Enum.map(& &1.amount)
              |> Enum.reduce(Decimal.new(0), &Decimal.add/2)

            %{
              label: ministry,
              value: Decimal.to_float(total)
            }
          end)
          |> Enum.sort_by(& &1.value, :desc)

        {:ok, revenue_by_ministry}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Gets the number of unique ministries with transactions.
  """
  def get_unique_ministries_count(actor) do
    query =
      Chms.Church.MinistryFunds
      |> Ash.Query.for_read(:read, %{}, actor: actor)

    case Ash.read(query, actor: actor) do
      {:ok, funds} ->
        count =
          funds
          |> Enum.map(& &1.ministry_name)
          |> Enum.uniq()
          |> length()

        {:ok, count}

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
