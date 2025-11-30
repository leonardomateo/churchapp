defmodule ChurchappWeb.CongregantsLive.ShowLive do
  use ChurchappWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    case Chms.Church.get_congregant_by_id(id) do
      {:ok, congregant} ->
        {:ok,
         socket
         |> assign(:page_title, "View Congregant")
         |> assign(:congregant, congregant)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Congregant not found")
         |> push_navigate(to: ~p"/congregants")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <%!-- Back Navigation and Edit Button --%>
      <div class="mb-6 flex items-center justify-between">
        <.link
          navigate={~p"/congregants"}
          class="flex items-center text-gray-400 hover:text-white transition-colors"
        >
          <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" />
          Back to List
        </.link>

        <.link
          navigate={~p"/congregants/#{@congregant}/edit"}
          class="inline-flex items-center px-4 py-2 text-sm font-medium text-white bg-primary-500 hover:bg-primary-600 rounded-md shadow-lg shadow-primary-500/20 transition-colors"
        >
          <.icon name="hero-pencil-square" class="mr-2 w-4 h-4" />
          Edit Member
        </.link>
      </div>

      <div class="bg-dark-800 shadow-xl rounded-lg border border-dark-700 overflow-hidden">
        <%!-- Member Header --%>
        <div class="px-6 py-8 border-b border-dark-700">
          <div class="flex items-center gap-6">
            <img
              src={"https://ui-avatars.com/api/?name=#{URI.encode(@congregant.first_name <> "+" <> @congregant.last_name)}&background=404040&color=D1D5DB&bold=true&size=256"}
              alt=""
              class="h-24 w-24 rounded-full object-cover border-2 border-dark-600"
            />

            <div class="flex-1">
              <div class="flex items-center gap-3 mb-3">
                <h1 class="text-2xl font-bold text-white">
                  {@congregant.first_name} {@congregant.last_name}
                </h1>
                <span class={[
                  "px-3 py-1 inline-flex text-xs font-medium rounded-full border",
                  @congregant.status == :member && "bg-green-900/60 text-green-400 border-green-800",
                  @congregant.status == :visitor && "bg-yellow-900/60 text-yellow-500 border-yellow-800",
                  @congregant.status == :deceased && "bg-gray-800 text-gray-400 border-gray-700",
                  @congregant.status == :honorific && "bg-blue-900/60 text-blue-400 border-blue-800"
                ]}>
                  {Phoenix.Naming.humanize(@congregant.status)}
                </span>
              </div>

              <div class="flex flex-wrap items-center gap-4 text-sm text-gray-400">
                <span class="flex items-center gap-1.5">
                  <.icon name="hero-identification" class="h-4 w-4" />
                  ID: {@congregant.member_id}
                </span>
                <span class="flex items-center gap-1.5">
                  <.icon name="hero-calendar" class="h-4 w-4" />
                  Member since {if @congregant.member_since, do: Calendar.strftime(@congregant.member_since, "%b %Y"), else: "Unknown"}
                </span>
                <%= if @congregant.is_leader do %>
                  <span class="flex items-center gap-1.5 text-primary-500">
                    <.icon name="hero-shield-check" class="h-4 w-4" />
                    Leader
                  </span>
                <% end %>
              </div>
            </div>
          </div>
        </div>

        <%!-- Member Details --%>
        <div class="p-8">
          <%!-- Personal Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-user" class="mr-2 h-5 w-5 text-primary-500" />
              Personal Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date of Birth
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {if @congregant.dob, do: Calendar.strftime(@congregant.dob, "%B %d, %Y"), else: "Not provided"}
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Role
                </dt>
                <dd class="mt-2 text-sm text-white">
                  <%= if @congregant.is_leader do %>
                    <span class="inline-flex items-center text-primary-500">
                      <.icon name="hero-shield-check" class="mr-1 w-4 h-4" />
                      Leader
                    </span>
                  <% else %>
                    Member
                  <% end %>
                </dd>
              </div>
            </dl>
          </div>

          <hr class="border-dark-700" />

          <%!-- Contact Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-phone" class="mr-2 h-5 w-5 text-primary-500" />
              Contact Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-3">
              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Mobile Phone
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {format_phone(@congregant.mobile_tel)}
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Home Phone
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {format_phone(@congregant.home_tel)}
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Work Phone
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {format_phone(@congregant.work_tel)}
                </dd>
              </div>
            </dl>
          </div>

          <hr class="border-dark-700" />

          <%!-- Address --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-map-pin" class="mr-2 h-5 w-5 text-primary-500" />
              Address
            </h3>
            <dl class="ml-6">
              <%= if @congregant.address do %>
                <dd class="text-sm text-white leading-relaxed">
                  <div>{@congregant.address}</div>
                  <%= if @congregant.suite do %>
                    <div>{@congregant.suite}</div>
                  <% end %>
                  <div>
                    {@congregant.city}<%= if @congregant.city && @congregant.state, do: ", " %>{@congregant.state} {@congregant.zip_code}
                  </div>
                  <div class="mt-2 text-gray-400">
                    {@congregant.country}
                  </div>
                </dd>
              <% else %>
                <dd class="text-sm text-gray-500 italic">
                  No address provided
                </dd>
              <% end %>
            </dl>
          </div>

          <hr class="border-dark-700" />

          <%!-- System Information --%>
          <div class="py-8">
            <h3 class="mb-6 ml-6 flex items-center text-lg font-medium leading-6 text-white">
              <.icon name="hero-clock" class="mr-2 h-5 w-5 text-primary-500" />
              Record Information
            </h3>
            <dl class="ml-6 grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Record Created
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {Calendar.strftime(@congregant.inserted_at, "%B %d, %Y at %I:%M %p")}
                </dd>
              </div>

              <div>
                <dt class="text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Record Last Updated
                </dt>
                <dd class="mt-2 text-sm text-white">
                  {Calendar.strftime(@congregant.updated_at, "%B %d, %Y at %I:%M %p")}
                </dd>
              </div>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Format phone number for display: (123) 456 - 7890
  defp format_phone(nil), do: "—"
  defp format_phone(""), do: "—"
  defp format_phone(phone) do
    digits = String.replace(phone, ~r/\D/, "")

    case String.length(digits) do
      10 ->
        "(#{String.slice(digits, 0, 3)}) #{String.slice(digits, 3, 3)} - #{String.slice(digits, 6, 4)}"
      _ ->
        phone  # Return as-is if not 10 digits
    end
  end
end
