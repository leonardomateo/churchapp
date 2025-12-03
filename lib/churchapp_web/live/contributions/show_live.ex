defmodule ChurchappWeb.ContributionsLive.ShowLive do
  use ChurchappWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    contribution = Ash.get!(Chms.Church.Contributions, id, load: [:congregant])

    {:ok,
     socket
     |> assign(:page_title, "View Contribution")
     |> assign(:contribution, contribution)}
  rescue
    _ ->
      {:ok,
       socket
       |> put_flash(:error, "Contribution not found")
       |> push_navigate(to: ~p"/contributions")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <%!-- Back Navigation and Edit Button --%>
      <div class="mb-6 flex items-center justify-between">
        <.link
          navigate={~p"/contributions"}
          class="flex items-center text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back to List
        </.link>

        <.link
          navigate={~p"/contributions/#{@contribution}/edit"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-pencil-square" class="mr-2 w-4 h-4" /> Edit Contribution
        </.link>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <%!-- Contribution Header --%>
        <div class="px-6 py-8 border-b border-dark-700">
          <div class="flex items-center gap-6">
            <div class="flex-shrink-0 w-20 h-20 rounded-full bg-primary-500/10 border-2 border-primary-500/20 flex items-center justify-center">
              <.icon name="hero-banknotes" class="h-10 w-10 text-primary-500" />
            </div>

            <div class="flex-1">
              <div class="flex items-center gap-3 mb-3">
                <h1 class="text-2xl font-bold text-white">
                  {@contribution.contribution_type}
                </h1>
                <span class="px-3 py-1 inline-flex text-xs font-medium rounded-full bg-green-900/60 text-green-400 border border-green-800">
                  ${Decimal.to_string(@contribution.revenue, :normal)}
                </span>
              </div>

              <div class="flex flex-wrap items-center gap-4 text-sm text-gray-400">
                <span class="flex items-center gap-1.5">
                  <.icon name="hero-calendar" class="h-4 w-4" />
                  {Calendar.strftime(@contribution.contribution_date, "%B %d, %Y")}
                </span>
                <span class="flex items-center gap-1.5">
                  <.icon name="hero-user" class="h-4 w-4" />
                  {@contribution.congregant.first_name} {@contribution.congregant.last_name}
                </span>
              </div>
            </div>
          </div>
        </div>

        <%!-- Contribution Details --%>
        <div class="p-8">
          <%!-- Contribution Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-document-text" class="mr-2 h-5 w-5 text-primary-500" />
              Contribution Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-primary-500/10 text-primary-500 border border-primary-500/20">
                    {@contribution.contribution_type}
                  </span>
                </dd>
              </div>

              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </dt>
                <dd class="mt-2 text-sm font-medium text-green-400">
                  ${Decimal.to_string(@contribution.revenue, :normal)}
                </dd>
              </div>

              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {Calendar.strftime(@contribution.contribution_date, "%B %d, %Y")}
                </dd>
              </div>
            </dl>
          </div>

          <hr class="border-dark-700" />

          <%!-- Congregant Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-user-circle" class="mr-2 h-5 w-5 text-primary-500" />
              Contributor Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <.link
                    navigate={~p"/congregants/#{@contribution.congregant}"}
                    class="text-primary-500 hover:text-primary-400 transition-colors"
                  >
                    {@contribution.congregant.first_name} {@contribution.congregant.last_name}
                  </.link>
                </dd>
              </div>

              <div class="flex flex-col h-full">
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Member ID
                </dt>
                <dd class="mt-2 text-sm text-white">
                  #{@contribution.congregant.member_id}
                </dd>
              </div>
            </dl>
          </div>

          <%= if @contribution.notes do %>
            <hr class="border-dark-700" />

            <%!-- Notes Section --%>
            <div class="py-8">
              <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
                <.icon name="hero-pencil" class="mr-2 h-5 w-5 text-primary-500" /> Notes
              </h3>
              <div class="ml-6">
                <dd class="text-sm text-white leading-relaxed whitespace-pre-wrap">
                  {@contribution.notes}
                </dd>
              </div>
            </div>
          <% end %>

          <hr class="border-dark-700" />

          <%!-- System Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-clock" class="mr-2 h-5 w-5 text-primary-500" /> Record Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Record Created
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {Calendar.strftime(@contribution.inserted_at, "%B %d, %Y at %I:%M %p")}
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Record Last Updated
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {Calendar.strftime(@contribution.updated_at, "%B %d, %Y at %I:%M %p")}
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
