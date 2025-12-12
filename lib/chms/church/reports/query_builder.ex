defmodule Chms.Church.Reports.QueryBuilder do
  @moduledoc """
  Dynamic Ash query builder for reports.
  Applies filters, sorting, and pagination based on resource configuration.
  """

  require Ash.Query
  require Ash.Expr

  @doc """
  Main entry point: builds and executes a query for the given resource configuration.
  Returns {:ok, results, metadata} or {:error, reason}.
  """
  def build_and_execute(resource_config, params, actor) do
    query = build_base_query(resource_config, actor)

    query =
      query
      |> apply_filters(resource_config, params)
      |> apply_sorting(resource_config, params)

    execute_with_pagination(query, params, actor)
  end

  # Build base query with preloads
  defp build_base_query(resource_config, actor) do
    resource_config.module
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> apply_preloads(resource_config.preloads)
  end

  defp apply_preloads(query, []), do: query

  defp apply_preloads(query, preloads) do
    Ash.Query.load(query, preloads)
  end

  # Apply all filters from params based on resource configuration
  defp apply_filters(query, resource_config, params) do
    filter_params = params[:filter_params] || %{}

    Enum.reduce(resource_config.filters, query, fn filter_config, acc_query ->
      filter_value = Map.get(filter_params, to_string(filter_config.key))

      if filter_value && filter_value != "" do
        apply_filter(acc_query, filter_config, filter_value)
      else
        acc_query
      end
    end)
  end

  # Apply individual filter based on query_builder type
  defp apply_filter(query, %{query_builder: :search_filter}, value) do
    # Congregant-specific multi-mode search (member_id, single word, multi-word)
    search_term = String.downcase(value)

    # Try to parse as integer for member_id search
    case Integer.parse(search_term) do
      {member_id, ""} ->
        # Pure integer - search by member_id
        Ash.Query.filter(query, member_id == ^member_id)

      _ ->
        # Not an integer - search by name
        parts = String.split(search_term, " ", trim: true)

        case parts do
          [] ->
            query

          [single_word] ->
            # Single word - search in first or last name
            Ash.Query.filter(
              query,
              contains(string_downcase(first_name), ^single_word) or
                contains(string_downcase(last_name), ^single_word)
            )

          [first_part, last_part] ->
            # Two words - assume "first last" pattern
            Ash.Query.filter(
              query,
              (contains(string_downcase(first_name), ^first_part) and
                 contains(string_downcase(last_name), ^last_part)) or
                (contains(string_downcase(first_name), ^last_part) and
                   contains(string_downcase(last_name), ^first_part))
            )

          _ ->
            # Multiple words - search full term in either name
            trimmed_term = String.trim(search_term)

            Ash.Query.filter(
              query,
              contains(string_downcase(first_name), ^trimmed_term) or
                contains(string_downcase(last_name), ^trimmed_term)
            )
        end
    end
  end

  defp apply_filter(query, %{query_builder: :contribution_search_filter}, value) do
    # Search in contribution type and contributor name
    search_term = String.downcase(value)
    parts = String.split(search_term, " ", trim: true)

    case parts do
      [] ->
        query

      [single_word] ->
        Ash.Query.filter(
          query,
          contains(string_downcase(contribution_type), ^single_word) or
            contains(string_downcase(congregant.first_name), ^single_word) or
            contains(string_downcase(congregant.last_name), ^single_word)
        )

      [first_part, last_part] ->
        Ash.Query.filter(
          query,
          (contains(string_downcase(congregant.first_name), ^first_part) and
             contains(string_downcase(congregant.last_name), ^last_part)) or
            contains(string_downcase(contribution_type), ^first_part) or
            contains(string_downcase(contribution_type), ^last_part)
        )

      _ ->
        trimmed_term = String.trim(search_term)

        Ash.Query.filter(
          query,
          contains(string_downcase(contribution_type), ^trimmed_term) or
            contains(string_downcase(congregant.first_name), ^trimmed_term) or
            contains(string_downcase(congregant.last_name), ^trimmed_term)
        )
    end
  end

  defp apply_filter(query, %{query_builder: :ministry_search_filter}, value) do
    # Search in ministry name and notes
    search_term = String.downcase(value)

    Ash.Query.filter(
      query,
      contains(string_downcase(ministry_name), ^search_term) or
        contains(string_downcase(notes), ^search_term)
    )
  end

  defp apply_filter(query, %{query_builder: :event_search_filter}, value) do
    # Search in event title and location
    search_term = String.downcase(value)

    Ash.Query.filter(
      query,
      contains(string_downcase(title), ^search_term) or
        contains(string_downcase(location), ^search_term)
    )
  end

  defp apply_filter(query, %{query_builder: :text_search_filter, field: field}, value) do
    # Generic text search with contains - use dynamic filter with keyword list
    search_term = String.downcase(value)
    filter_expr = [{field, [contains: search_term]}]
    Ash.Query.filter(query, ^filter_expr)
  end

  defp apply_filter(query, %{query_builder: :enum_filter, field: field}, value) do
    # Enum field filtering (status, gender, etc.)
    enum_value = String.to_existing_atom(value)
    filter_expr = [{field, [eq: enum_value]}]
    Ash.Query.filter(query, ^filter_expr)
  end

  defp apply_filter(query, %{query_builder: :string_filter, field: field}, value) do
    # Exact string matching
    filter_expr = [{field, [eq: value]}]
    Ash.Query.filter(query, ^filter_expr)
  end

  defp apply_filter(query, %{query_builder: :boolean_filter, field: field}, value) do
    # Boolean field filtering
    bool_value = value in ["true", true, "1"]
    filter_expr = [{field, [eq: bool_value]}]
    Ash.Query.filter(query, ^filter_expr)
  end

  defp apply_filter(
         query,
         %{query_builder: :date_range_filter, field: field, operator: operator},
         value
       ) do
    # Date range filtering
    case Date.from_iso8601(value) do
      {:ok, date} ->
        filter_expr =
          case operator do
            :gte -> [{field, [greater_than_or_equal: date]}]
            :lte -> [{field, [less_than_or_equal: date]}]
            :eq -> [{field, [eq: date]}]
            _ -> nil
          end

        if filter_expr, do: Ash.Query.filter(query, ^filter_expr), else: query

      _ ->
        query
    end
  end

  defp apply_filter(
         query,
         %{query_builder: :datetime_range_filter, field: field, operator: operator},
         value
       ) do
    # Datetime range filtering with start/end of day conversion
    case Date.from_iso8601(value) do
      {:ok, date} ->
        datetime =
          case operator do
            :gte -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
            :lte -> DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")
            :eq -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
            _ -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
          end

        filter_expr =
          case operator do
            :gte -> [{field, [greater_than_or_equal: datetime]}]
            :lte -> [{field, [less_than_or_equal: datetime]}]
            :eq -> [{field, [eq: datetime]}]
            _ -> nil
          end

        if filter_expr, do: Ash.Query.filter(query, ^filter_expr), else: query

      _ ->
        query
    end
  end

  defp apply_filter(
         query,
         %{query_builder: :number_range_filter, field: field, operator: operator},
         value
       ) do
    # Numeric range filtering with Decimal support
    case Decimal.parse(value) do
      {decimal_value, _} ->
        apply_number_filter(query, field, operator, decimal_value)

      :error ->
        # Try integer parse as fallback
        case Integer.parse(value) do
          {int_value, _} ->
            apply_number_filter(query, field, operator, int_value)

          :error ->
            query
        end
    end
  end

  defp apply_filter(query, _filter_config, _value) do
    # Unknown filter type - return query unchanged
    query
  end

  defp apply_number_filter(query, field, operator, num_value) do
    filter_expr =
      case operator do
        :gte -> [{field, [greater_than_or_equal: num_value]}]
        :lte -> [{field, [less_than_or_equal: num_value]}]
        :eq -> [{field, [eq: num_value]}]
        _ -> nil
      end

    if filter_expr, do: Ash.Query.filter(query, ^filter_expr), else: query
  end

  # Apply sorting based on params or default
  defp apply_sorting(query, resource_config, params) do
    sort_by = params[:sort_by] || elem(resource_config.default_sort, 0)
    sort_dir = params[:sort_dir] || elem(resource_config.default_sort, 1)

    # Validate sort field is in sortable_fields
    if sort_by in resource_config.sortable_fields do
      Ash.Query.sort(query, [{sort_by, sort_dir}])
    else
      # Use default sort if invalid field requested
      Ash.Query.sort(query, [resource_config.default_sort])
    end
  end

  # Execute query with pagination
  defp execute_with_pagination(query, params, actor) do
    page = params[:page] || 1
    per_page = params[:per_page] || 25

    # Calculate offset
    offset = (page - 1) * per_page

    # Get total count for metadata
    count_query = query
    total_count = Ash.count!(count_query, actor: actor)

    # Apply pagination
    paginated_query =
      query
      |> Ash.Query.limit(per_page)
      |> Ash.Query.offset(offset)

    case Ash.read(paginated_query, actor: actor) do
      {:ok, results} ->
        metadata = %{
          page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: ceil(total_count / per_page)
        }

        {:ok, results, metadata}

      {:error, error} ->
        {:error, error}
    end
  end
end
