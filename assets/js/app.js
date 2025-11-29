// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/churchapp"
import topbar from "../vendor/topbar"

// Mobile Menu Hook
const MobileMenu = {
  mounted() {
    this.menuOverlay = document.getElementById("mobile-menu-overlay")
    this.menu = document.getElementById("mobile-menu")
    this.backdrop = document.getElementById("mobile-menu-backdrop")
    this.isOpen = false

    this.openMenu = () => {
      if (this.menuOverlay && this.menu) {
        this.isOpen = true
        this.menuOverlay.classList.remove("hidden")
        setTimeout(() => {
          this.menu.classList.remove("-translate-x-full")
        }, 10)
      }
    }

    this.closeMenu = () => {
      if (this.menuOverlay && this.menu) {
        this.isOpen = false
        this.menu.classList.add("-translate-x-full")
        setTimeout(() => {
          this.menuOverlay.classList.add("hidden")
        }, 300)
      }
    }

    this.toggleMenu = () => {
      if (this.isOpen) {
        this.closeMenu()
      } else {
        this.openMenu()
      }
    }

    this.el.addEventListener("click", this.toggleMenu)
    this.backdrop?.addEventListener("click", this.closeMenu)

    // Close menu on navigation
    this.handleEvent("close-mobile-menu", () => this.closeMenu())
  },

  destroyed() {
    this.el.removeEventListener("click", this.toggleMenu)
    this.backdrop?.removeEventListener("click", this.closeMenu)
  }
}

// Theme Dropdown Hook
const ThemeDropdown = {
  mounted() {
    this.button = document.getElementById("theme-toggle-btn")
    this.menu = document.getElementById("theme-menu")

    this.toggleDropdown = (e) => {
      e.stopPropagation()
      // Check actual menu state instead of tracking with variable
      const isCurrentlyHidden = this.menu.classList.contains("hidden")
      if (isCurrentlyHidden) {
        this.menu.classList.remove("hidden")
      } else {
        this.menu.classList.add("hidden")
      }
    }

    this.closeDropdown = (e) => {
      if (!this.el.contains(e.target)) {
        this.menu.classList.add("hidden")
      }
    }

    this.button?.addEventListener("click", this.toggleDropdown)
    document.addEventListener("click", this.closeDropdown)
  },

  destroyed() {
    this.button?.removeEventListener("click", this.toggleDropdown)
    document.removeEventListener("click", this.closeDropdown)
  }
}

// Phone Number Format Hook - formats as (123) 456 - 7890
const PhoneFormat = {
  mounted() {
    this.el.addEventListener("input", this.formatPhone.bind(this))
    // Format existing value on mount
    if (this.el.value) {
      this.el.value = this.formatPhoneNumber(this.el.value)
    }
  },

  formatPhone(e) {
    const input = e.target
    const cursorPos = input.selectionStart
    const oldLength = input.value.length
    
    input.value = this.formatPhoneNumber(input.value)
    
    // Adjust cursor position after formatting
    const newLength = input.value.length
    const diff = newLength - oldLength
    input.setSelectionRange(cursorPos + diff, cursorPos + diff)
  },

  formatPhoneNumber(value) {
    // Remove all non-digit characters
    const digits = value.replace(/\D/g, "")
    
    // Limit to 10 digits
    const limited = digits.slice(0, 10)
    
    // Format based on length
    if (limited.length === 0) {
      return ""
    } else if (limited.length <= 3) {
      return `(${limited}`
    } else if (limited.length <= 6) {
      return `(${limited.slice(0, 3)}) ${limited.slice(3)}`
    } else {
      return `(${limited.slice(0, 3)}) ${limited.slice(3, 6)} - ${limited.slice(6)}`
    }
  },

  destroyed() {
    this.el.removeEventListener("input", this.formatPhone.bind(this))
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, MobileMenu, ThemeDropdown, PhoneFormat},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Theme toggle functionality
const THEME_KEY = "theme"
const THEMES = ["system", "light", "dark"]

// Apply theme on page load
const applyTheme = (theme) => {
  const html = document.documentElement
  
  if (theme === "system") {
    const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    html.setAttribute("data-theme", prefersDark ? "dark" : "light")
  } else {
    html.setAttribute("data-theme", theme)
  }
  
  localStorage.setItem(THEME_KEY, theme)
}

// Expose setTheme function globally for onclick handlers
window.setTheme = (theme) => {
  if (THEMES.includes(theme)) {
    applyTheme(theme)
  }
}

// Initialize theme from localStorage or default to dark
const savedTheme = localStorage.getItem(THEME_KEY) || "dark"
applyTheme(savedTheme)

// Watch for system theme changes when in system mode
window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
  const currentTheme = localStorage.getItem(THEME_KEY)
  if (currentTheme === "system") {
    applyTheme("system")
  }
})

// Close mobile menu on LiveView navigation
window.addEventListener("phx:navigate", () => {
  const menuOverlay = document.getElementById("mobile-menu-overlay")
  const menu = document.getElementById("mobile-menu")
  if (menuOverlay && menu) {
    menu.classList.add("-translate-x-full")
    menuOverlay.classList.add("hidden")
  }
})


// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

