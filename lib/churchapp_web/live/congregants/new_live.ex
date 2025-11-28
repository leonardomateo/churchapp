defmodule ChurchappWeb.CongregantsLive.NewLive do
  use ChurchappWeb, :live_view

  alias Chms.Church.Congregants
  alias AshPhoenix.Form

  def mount(_params, _session, socket) do
    generated_id = Enum.random(1_000_000..9_999_999)

    form =
      Congregants
      |> Form.for_create(:create,
        api: Chms.Church,
        forms: [auto?: true]
      )
      |> Form.validate(%{"generated_member_id" => generated_id})
      |> to_form()

    socket =
      socket
      |> assign(:page_title, "New Congregant")
      |> assign(:form, form)
      |> assign(:generated_id, generated_id)

    {:ok, socket}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    form = Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.form, params: params) do
      {:ok, _congregant} ->
        {:noreply,
         socket
         |> put_flash(:info, "Congregant created successfully")
         |> push_navigate(to: ~p"/congregants")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto">
      <div class="flex items-center gap-4 mb-6">
        <.link navigate={~p"/congregants"} class="btn btn-circle btn-ghost">
          <.icon name="hero-arrow-left" class="w-6 h-6" />
        </.link>
        <div>
          <h1 class="text-3xl font-bold">New Congregant</h1>
          <p class="text-base-content/60">Add a new member to the church database</p>
        </div>
      </div>

      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-6">

            <!-- Personal Information Section -->
            <div class="divider text-primary font-semibold">Personal Information</div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <!-- Member ID (Auto-generated) -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Member ID</span>
                  <span class="label-text-alt text-base-content/60">(Auto-generated)</span>
                </label>
                <!-- Hidden input to pass the argument to the action -->
                <input type="hidden" name={@form[:generated_member_id].name} value={@generated_id} />
                <!-- Visible readonly input for display -->
                <input
                  type="text"
                  class="input input-bordered w-full bg-base-300 text-base-content cursor-not-allowed font-mono"
                  value={@generated_id}
                  readonly
                />
              </div>

              <!-- Status -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Status</span>
                </label>
                <.input
                  field={@form[:status]}
                  type="select"
                  options={[
                    {"Member", :member},
                    {"Visitor", :visitor},
                    {"Honorific", :honorific},
                    {"Deceased", :deceased}
                  ]}
                  class="select select-bordered w-full"
                />
              </div>

              <!-- First Name -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">First Name</span>
                </label>
                <.input field={@form[:first_name]} type="text" class="input input-bordered w-full" placeholder="John" />
              </div>

              <!-- Last Name -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Last Name</span>
                </label>
                <.input field={@form[:last_name]} type="text" class="input input-bordered w-full" placeholder="Doe" />
              </div>

              <!-- Date of Birth -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Date of Birth</span>
                </label>
                <.input field={@form[:dob]} type="date" class="input input-bordered w-full" />
              </div>

              <!-- Member Since -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Member Since</span>
                </label>
                <.input field={@form[:member_since]} type="date" class="input input-bordered w-full" />
              </div>
            </div>

            <!-- Contact Information Section -->
            <div class="divider text-primary font-semibold">Contact Information</div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <!-- Mobile Phone -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Mobile Phone</span>
                </label>
                <.input field={@form[:mobile_tel]} type="tel" class="input input-bordered w-full" placeholder="(555) 123-4567" />
              </div>

              <!-- Home Phone -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Home Phone</span>
                </label>
                <.input field={@form[:home_tel]} type="tel" class="input input-bordered w-full" placeholder="(555) 123-4567" />
              </div>

              <!-- Work Phone -->
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Work Phone</span>
                </label>
                <.input field={@form[:work_tel]} type="tel" class="input input-bordered w-full" placeholder="(555) 123-4567" />
              </div>
            </div>

            <!-- Address Section -->
            <div class="divider text-primary font-semibold">Address</div>

            <div class="space-y-4">
              <div class="form-control w-full">
                <label class="label">
                  <span class="label-text">Street Address</span>
                </label>
                <.input field={@form[:address]} type="text" class="input input-bordered w-full" placeholder="123 Main St" />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="form-control w-full">
                  <label class="label">
                    <span class="label-text">City</span>
                  </label>
                  <.input field={@form[:city]} type="text" class="input input-bordered w-full" placeholder="Springfield" />
                </div>

                <div class="form-control w-full">
                  <label class="label">
                    <span class="label-text">State/Province</span>
                  </label>
                  <.input field={@form[:state]} type="text" class="input input-bordered w-full" placeholder="IL" />
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div class="form-control w-full">
                  <label class="label">
                    <span class="label-text">Zip Code</span>
                  </label>
                  <.input field={@form[:zip_code]} type="text" class="input input-bordered w-full" placeholder="62704" />
                </div>

                <div class="form-control w-full">
                  <label class="label">
                    <span class="label-text">Country</span>
                  </label>
                  <.input field={@form[:country]} type="text" class="input input-bordered w-full" placeholder="USA" />
                </div>

                <div class="form-control w-full">
                  <label class="label">
                    <span class="label-text">Suite/Apt</span>
                  </label>
                  <.input field={@form[:suite]} type="text" class="input input-bordered w-full" placeholder="Apt 4B" />
                </div>
              </div>
            </div>

            <!-- Leadership -->
            <div class="divider text-primary font-semibold">Role</div>

            <div class="form-control">
              <label class="label cursor-pointer justify-start gap-4">
                <.input field={@form[:is_leader]} type="checkbox" class="checkbox checkbox-primary" />
                <span class="label-text font-medium">Is a Leader?</span>
              </label>
            </div>

            <!-- Actions -->
            <div class="card-actions justify-end mt-8 pt-4 border-t border-base-200">
              <.link navigate={~p"/congregants"} class="btn btn-ghost">Cancel</.link>
              <button class="btn btn-primary min-w-[120px]" phx-disable-with="Saving...">
                <.icon name="hero-check" class="w-5 h-5" />
                Save Congregant
              </button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
