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
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/congregants"} class="btn btn-circle btn-ghost">
            <.icon name="hero-arrow-left" class="w-6 h-6" />
          </.link>
          <div>
            <h1 class="text-3xl font-bold">
              {@congregant.first_name} {@congregant.last_name}
            </h1>
            <div class="flex items-center gap-2 mt-1 text-base-content/60">
              <span class="font-mono text-sm">Congregant ID: {@congregant.member_id}</span>
              <span>•</span>
              <span>Joined {if @congregant.member_since, do: Calendar.strftime(@congregant.member_since, "%B %d, %Y"), else: "Unknown date"}</span>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <.link navigate={~p"/congregants/#{@congregant}/edit"} class="btn btn-primary gap-2">
            <.icon name="hero-pencil-square" class="w-5 h-5" />
            Edit
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Main Info Card -->
        <div class="col-span-1 lg:col-span-2 space-y-6">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title mb-4 text-primary">
                <.icon name="hero-user" class="w-6 h-6" />
                Personal Information
              </h2>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <div class="text-sm font-semibold text-base-content/60 uppercase tracking-wider mb-1">Status</div>
                  <div class={[
                    "badge badge-lg gap-1",
                    @congregant.status == :member && "badge-success",
                    @congregant.status == :visitor && "badge-info",
                    @congregant.status == :deceased && "badge-ghost",
                    @congregant.status == :honorific && "badge-warning"
                  ]}>
                    {Phoenix.Naming.humanize(@congregant.status)}
                  </div>
                </div>

                <div>
                  <div class="text-sm font-semibold text-base-content/60 uppercase tracking-wider mb-1">Role</div>
                  <%= if @congregant.is_leader do %>
                    <div class="badge badge-accent gap-1">
                      <.icon name="hero-shield-check" class="w-4 h-4" />
                      Leader
                    </div>
                  <% else %>
                    <span class="text-base-content">Member</span>
                  <% end %>
                </div>

                <div>
                  <div class="text-sm font-semibold text-base-content/60 uppercase tracking-wider mb-1">Date of Birth</div>
                  <div class="text-lg">
                    {if @congregant.dob, do: Calendar.strftime(@congregant.dob, "%B %d, %Y"), else: "Not provided"}
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title mb-4 text-primary">
                <.icon name="hero-map-pin" class="w-6 h-6" />
                Address
              </h2>

              <%= if @congregant.address do %>
                <div class="text-lg">
                  <div>{@congregant.address} {if @congregant.suite, do: "Ste #{@congregant.suite}"}</div>
                  <div>
                    {@congregant.city}{if @congregant.city && @congregant.state, do: ","} {@congregant.state} {@congregant.zip_code}
                  </div>
                  <div class="text-base-content/60 mt-1">{@congregant.country}</div>
                </div>
              <% else %>
                <div class="text-base-content/60 italic">No address information provided</div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Sidebar Info -->
        <div class="col-span-1 space-y-6">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title mb-4 text-primary">
                <.icon name="hero-phone" class="w-6 h-6" />
                Contact Details
              </h2>

              <div class="space-y-4">
                <div>
                  <div class="text-sm font-semibold text-base-content/60 uppercase tracking-wider mb-1">Mobile</div>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-device-phone-mobile" class="w-5 h-5 opacity-60" />
                    <span>{if @congregant.mobile_tel, do: @congregant.mobile_tel, else: "—"}</span>
                  </div>
                </div>

                <div>
                  <div class="text-sm font-semibold text-base-content/60 uppercase tracking-wider mb-1">Home</div>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-phone" class="w-5 h-5 opacity-60" />
                    <span>{if @congregant.home_tel, do: @congregant.home_tel, else: "—"}</span>
                  </div>
                </div>

                <div>
                  <div class="text-sm font-semibold text-base-content/60 uppercase tracking-wider mb-1">Work</div>
                  <div class="flex items-center gap-2">
                    <.icon name="hero-briefcase" class="w-5 h-5 opacity-60" />
                    <span>{if @congregant.work_tel, do: @congregant.work_tel, else: "—"}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title mb-4 text-primary">
                <.icon name="hero-clock" class="w-6 h-6" />
                System Info
              </h2>

              <div class="space-y-4 text-sm">
                <div>
                  <div class="text-base-content/60">Created At</div>
                  <div>{Calendar.strftime(@congregant.inserted_at, "%b %d, %Y %I:%M %p")}</div>
                </div>
                <div>
                  <div class="text-base-content/60">Last Updated</div>
                  <div>{Calendar.strftime(@congregant.updated_at, "%b %d, %Y %I:%M %p")}</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
