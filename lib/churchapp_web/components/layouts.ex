defmodule ChurchappWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ChurchappWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  # Remove the manual definition of app(assigns) since it's now handled by embed_templates
  # pointing to layouts/app.html.heex which we just created.

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative" id="theme-dropdown" phx-hook="ThemeDropdown">
      <button
        type="button"
        id="theme-toggle-btn"
        class="p-2 rounded-lg text-gray-400 hover:text-white hover:bg-dark-700 transition-colors focus:outline-none focus:ring-2 focus:ring-primary-500"
        aria-label="Toggle theme"
      >
        <%!-- Show sun in dark mode, moon in light mode --%>
        <.icon name="hero-sun" class="size-5 hidden [[data-theme=dark]_&]:block" />
        <.icon name="hero-moon" class="size-5 block [[data-theme=dark]_&]:hidden" />
      </button>

      <%!-- Dropdown menu --%>
      <div
        id="theme-menu"
        class="absolute right-0 mt-2 w-36 bg-dark-800 border border-dark-700 rounded-lg shadow-xl z-50 hidden"
      >
        <div class="py-1">
          <button
            type="button"
            class="w-full flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-700 hover:text-white transition-colors"
            onclick="window.setTheme('light'); document.getElementById('theme-menu').classList.add('hidden');"
          >
            <.icon name="hero-sun" class="size-4 mr-3" /> Light
          </button>
          <button
            type="button"
            class="w-full flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-700 hover:text-white transition-colors"
            onclick="window.setTheme('dark'); document.getElementById('theme-menu').classList.add('hidden');"
          >
            <.icon name="hero-moon" class="size-4 mr-3" /> Dark
          </button>
          <button
            type="button"
            class="w-full flex items-center px-4 py-2 text-sm text-gray-300 hover:bg-dark-700 hover:text-white transition-colors"
            onclick="window.setTheme('system'); document.getElementById('theme-menu').classList.add('hidden');"
          >
            <.icon name="hero-computer-desktop" class="size-4 mr-3" /> System
          </button>
        </div>
      </div>
    </div>
    """
  end
end
