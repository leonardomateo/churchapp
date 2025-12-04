defmodule ChurchappWeb.Router do
  use ChurchappWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChurchappWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", ChurchappWeb do
    pipe_through :browser

    # Public routes
    get "/", PageController, :home

    # Controller-based auth routes (callbacks, sign-out)
    auth_routes AuthController, Churchapp.Accounts.User, path: "/auth"
    sign_out_route AuthController
  end

  # LiveView auth routes - must be in separate scope
  scope "/", ChurchappWeb do
    pipe_through :browser

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{ChurchappWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    ChurchappWeb.AuthOverrides,
                    Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                  ]

    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  ChurchappWeb.AuthOverrides,
                  Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI
                ]

    confirm_route Churchapp.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [ChurchappWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]

    magic_sign_in_route(Churchapp.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [ChurchappWeb.AuthOverrides, Elixir.AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Protected routes - require authentication
  scope "/", ChurchappWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated,
      on_mount: [
        {ChurchappWeb.LiveUserAuth, :live_user_required}
      ] do
      live "/congregants", CongregantsLive.IndexLive, :index
      live "/congregants/new", CongregantsLive.NewLive, :new
      live "/congregants/:id", CongregantsLive.ShowLive, :show
      live "/congregants/:id/edit", CongregantsLive.EditLive, :edit

      live "/contributions", ContributionsLive.IndexLive, :index
      live "/contributions/new", ContributionsLive.NewLive, :new
      live "/contributions/:id", ContributionsLive.ShowLive, :show
      live "/contributions/:id/edit", ContributionsLive.EditLive, :edit
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChurchappWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:churchapp, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChurchappWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:churchapp, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/", domains: [Chms.Church, Churchapp.Accounts]
    end
  end
end
