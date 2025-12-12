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

// Import Chart.js hooks
import {BarChart, PieChart, DoughnutChart} from "./hooks/charts.js"

// Import FullCalendar
import { Calendar } from '@fullcalendar/core'
import dayGridPlugin from '@fullcalendar/daygrid'
import listPlugin from '@fullcalendar/list'
import interactionPlugin from '@fullcalendar/interaction'
import { RRule } from 'rrule'

// Modal Portal Hook - moves modal to body to avoid form nesting issues
const ModalPortal = {
  mounted() {
    // Move the modal to body to avoid form nesting
    document.body.appendChild(this.el)
  },
  destroyed() {
    // Clean up - remove from body if still there
    if (this.el.parentNode === document.body) {
      document.body.removeChild(this.el)
    }
  }
}

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

// Image Upload Hook - handles drag-and-drop for the dropzone
const ImageUpload = {
  mounted() {
    this.dropzoneEl = document.getElementById("image-upload-dropzone")
    this.inputEl = document.getElementById("image-upload-input")
    
    // Handle drag and drop on the dropzone
    if (this.dropzoneEl) {
      this.dropzoneEl.addEventListener("dragover", this.handleDragOver.bind(this))
      this.dropzoneEl.addEventListener("dragleave", this.handleDragLeave.bind(this))
      this.dropzoneEl.addEventListener("drop", this.handleDrop.bind(this))
    }
  },

  handleDragOver(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dropzoneEl.classList.add("border-primary-500", "bg-primary-500/10")
  },

  handleDragLeave(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dropzoneEl.classList.remove("border-primary-500", "bg-primary-500/10")
  },

  handleDrop(e) {
    e.preventDefault()
    e.stopPropagation()
    this.dropzoneEl.classList.remove("border-primary-500", "bg-primary-500/10")
    
    const files = e.dataTransfer.files
    if (files.length > 0) {
      const file = files[0]
      
      // Check file size (5MB limit)
      if (file.size > 5_000_000) {
        alert("File size must be less than 5MB")
        return
      }
      
      // Check file type
      if (!file.type.startsWith('image/')) {
        alert("File must be an image")
        return
      }
      
      // Set the file to the hidden input
      if (this.inputEl) {
        const dataTransfer = new DataTransfer()
        dataTransfer.items.add(file)
        this.inputEl.files = dataTransfer.files
        
        // Trigger the change event to notify LiveView
        const event = new Event("change", { bubbles: true })
        this.inputEl.dispatchEvent(event)
      }
    }
  },

  destroyed() {
    if (this.dropzoneEl) {
      this.dropzoneEl.removeEventListener("dragover", this.handleDragOver.bind(this))
      this.dropzoneEl.removeEventListener("dragleave", this.handleDragLeave.bind(this))
      this.dropzoneEl.removeEventListener("drop", this.handleDrop.bind(this))
    }
  }
}

// LocalTime Hook - displays UTC datetime in user's local timezone
const LocalTime = {
  mounted() {
    this.formatTime()
  },
  
  updated() {
    this.formatTime()
  },
  
  formatTime() {
    const utcValue = this.el.dataset.utc
    const format = this.el.dataset.format || "full" // full, date, time
    
    if (!utcValue) return
    
    try {
      // Parse the UTC datetime
      let date
      if (utcValue.endsWith('Z') || utcValue.includes('+')) {
        date = new Date(utcValue)
      } else {
        // Treat as UTC if no timezone indicator
        date = new Date(utcValue + 'Z')
      }
      
      if (isNaN(date.getTime())) return
      
      let formatted
      switch(format) {
        case "date":
          formatted = date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
          })
          break
        case "time":
          formatted = date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
          })
          break
        case "datetime":
          formatted = date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
          }) + ' at ' + date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
          })
          break
        case "short":
          formatted = date.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
          })
          break
        default: // "full"
          formatted = date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
          }) + ' at ' + date.toLocaleTimeString('en-US', {
            hour: 'numeric',
            minute: '2-digit',
            hour12: true
          })
      }
      
      this.el.textContent = formatted
    } catch (e) {
      console.error("Error formatting local time:", e)
    }
  }
}

// AutoFocus Hook - automatically focuses an input element when mounted
const AutoFocus = {
  mounted() {
    // Small delay to ensure modal animation completes
    setTimeout(() => {
      this.el.focus()
      this.el.select()
    }, 100)
  }
}

// DateTimeInput Hook - handles UTC <-> local conversion for datetime inputs
// Used with the DatetimeInput component for proper timezone handling
const DateTimeInput = {
  mounted() {
    this.localInput = this.el.querySelector('input[type="datetime-local"]')
    this.hiddenInput = this.el.querySelector('input[type="hidden"]')
    
    if (!this.localInput || !this.hiddenInput) return
    
    // Convert existing UTC value to local for display
    const utcValue = this.localInput.dataset.utcValue
    if (utcValue) {
      try {
        const date = new Date(utcValue)
        if (!isNaN(date.getTime())) {
          this.localInput.value = this.formatDatetimeLocal(date)
        }
      } catch (e) {
        console.error("Error parsing UTC value:", e)
      }
    }
    
    // On change, convert local to UTC and update hidden input
    this.localInput.addEventListener("change", this.handleChange.bind(this))
    this.localInput.addEventListener("input", this.handleInput.bind(this))
  },
  
  handleChange() {
    this.updateHiddenInput()
    // Close the picker
    this.localInput.blur()
  },
  
  handleInput() {
    this.updateHiddenInput()
  },
  
  updateHiddenInput() {
    if (this.localInput.value) {
      // datetime-local value is in local time, convert to UTC ISO string
      const localDate = new Date(this.localInput.value)
      if (!isNaN(localDate.getTime())) {
        this.hiddenInput.value = localDate.toISOString()
      }
    } else {
      this.hiddenInput.value = ""
    }
    // Trigger input event on hidden input for LiveView form tracking
    this.hiddenInput.dispatchEvent(new Event('input', { bubbles: true }))
  },
  
  formatDatetimeLocal(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    return `${year}-${month}-${day}T${hours}:${minutes}`
  },
  
  destroyed() {
    if (this.localInput) {
      this.localInput.removeEventListener("change", this.handleChange.bind(this))
      this.localInput.removeEventListener("input", this.handleInput.bind(this))
    }
  }
}

// DatePickerClose Hook - simple hook to close date picker after selection
const DatePickerClose = {
  mounted() {
    this.el.addEventListener("change", this.handleChange.bind(this))
  },

  handleChange() {
    // Blur the input to close the date picker
    this.el.blur()
  },

  destroyed() {
    this.el.removeEventListener("change", this.handleChange.bind(this))
  }
}

// DatePicker Hook - handles date/datetime inputs
// For datetime-local inputs on EDIT forms: converts UTC from server to local for display
// New entries work normally - user enters local time, server stores as UTC
const DatePicker = {
  mounted() {
    this.el.addEventListener("change", this.handleChange.bind(this))
    
    // For datetime-local inputs with existing values, convert UTC to local for display
    // Only do this if the value looks like a UTC datetime (contains Z or full ISO format)
    if (this.el.type === "datetime-local" && this.el.value) {
      this.convertUTCToLocalIfNeeded()
    }
  },

  // Convert UTC datetime to local time for display in the input (edit forms only)
  convertUTCToLocalIfNeeded() {
    const utcValue = this.el.value
    if (!utcValue) return
    
    // Only convert if this looks like a UTC ISO string (has Z or timezone offset)
    // datetime-local format is YYYY-MM-DDTHH:mm - if it matches exactly, leave it alone
    if (!utcValue.endsWith('Z') && !utcValue.includes('+') && utcValue.length <= 16) {
      return // Already in local datetime-local format
    }
    
    try {
      const date = new Date(utcValue)
      
      if (!isNaN(date.getTime())) {
        // Format for datetime-local input in local time
        const localValue = this.formatDatetimeLocal(date)
        this.el.value = localValue
      }
    } catch (e) {
      console.error("Error converting UTC to local:", e)
    }
  },

  formatDatetimeLocal(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    return `${year}-${month}-${day}T${hours}:${minutes}`
  },

  handleChange() {
    // Blur the input to close the date picker
    this.el.blur()
  },

  destroyed() {
    this.el.removeEventListener("change", this.handleChange.bind(this))
  }
}

// CsvDownload Hook - handles CSV file download from LiveView events
const CsvDownload = {
  mounted() {
    this.handleEvent("download_csv", ({content, filename}) => {
      // Create blob from CSV content
      const blob = new Blob([content], { type: "text/csv;charset=utf-8;" })

      // Create download link
      const link = document.createElement("a")
      const url = URL.createObjectURL(blob)
      link.setAttribute("href", url)
      link.setAttribute("download", filename)
      link.style.visibility = "hidden"

      // Trigger download
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)

      // Clean up
      URL.revokeObjectURL(url)
    })
  }
}

// FullCalendar Hook - Event Calendar with month/week/day/list views
const EventCalendar = {
  mounted() {
    this.calendar = null
    this.currentFilter = null
    this.isAdmin = this.el.dataset.isAdmin === "true"
    
    this.initCalendar()
    
    // Handle events from LiveView
    this.handleEvent("events_loaded", ({events}) => {
      this.updateEvents(events)
    })
    
    this.handleEvent("event_created", ({event}) => {
      this.calendar.addEvent(this.transformEvent(event))
    })
    
    this.handleEvent("event_updated", ({event}) => {
      const existingEvent = this.calendar.getEventById(event.id)
      if (existingEvent) {
        existingEvent.remove()
      }
      this.calendar.addEvent(this.transformEvent(event))
    })
    
    this.handleEvent("event_deleted", ({id}) => {
      const existingEvent = this.calendar.getEventById(id)
      if (existingEvent) {
        existingEvent.remove()
      }
    })
    
    this.handleEvent("filter_changed", ({filter}) => {
      this.currentFilter = filter
      this.calendar.refetchEvents()
    })

    // Handle iCal download
    this.handleEvent("download_ical", ({content, filename}) => {
      const blob = new Blob([content], { type: "text/calendar;charset=utf-8;" })
      const link = document.createElement("a")
      const url = URL.createObjectURL(blob)
      link.setAttribute("href", url)
      link.setAttribute("download", filename)
      link.style.visibility = "hidden"
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
    })
  },
  
  initCalendar() {
    const calendarEl = this.el
    
    this.calendar = new Calendar(calendarEl, {
      plugins: [dayGridPlugin, listPlugin, interactionPlugin],
      initialView: 'dayGridMonth',
      timeZone: 'local',  // Use local timezone without conversion (times are stored as-is)
      headerToolbar: {
        left: 'title',
        center: '',
        right: 'today prev,next'
      },
      buttonText: {
        today: 'Today'
      },
      height: 'auto',
      editable: false,
      selectable: this.isAdmin,
      selectMirror: true,
      dayMaxEvents: true,  // Show "more" link when events overflow
      dayMaxEventRows: 4,  // Show up to 4 rows of events before "more" link
      weekends: true,
      eventDisplay: 'block',  // Use block display for better text visibility
      
      // Responsive configuration
      windowResize: (arg) => {
        // Adjust dayMaxEventRows based on screen size
        if (window.innerWidth < 640) {
          this.calendar.setOption('dayMaxEventRows', 2)
        } else if (window.innerWidth < 1024) {
          this.calendar.setOption('dayMaxEventRows', 3)
        } else {
          this.calendar.setOption('dayMaxEventRows', 4)
        }
      },
      nowIndicator: true,
      eventTimeFormat: {
        hour: 'numeric',
        minute: '2-digit',
        meridiem: 'short'
      },
      
      // List view formatting - show day name in main header, hide side day name
      listDayFormat: { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' },
      listDaySideFormat: false,
      
      // Event sources - fetch from LiveView
      events: (info, successCallback, failureCallback) => {
        this.pushEvent("fetch_events", {
          start: info.startStr,
          end: info.endStr,
          filter: this.currentFilter
        }, (reply, ref) => {
          if (reply.events) {
            const transformedEvents = reply.events.map(e => this.transformEvent(e))
            // Expand recurring events
            const expandedEvents = this.expandRecurringEvents(transformedEvents, info.start, info.end)
            successCallback(expandedEvents)
          } else {
            failureCallback(new Error("Failed to fetch events"))
          }
        })
      },
      
      // Click on a date to create new event (admin only)
      dateClick: (info) => {
        if (this.isAdmin) {
          this.pushEvent("date_clicked", {
            date: info.dateStr,
            allDay: false  // Always default to timed event, not all-day
          })
        }
      },
      
      // Click on an event to view/edit
      eventClick: (info) => {
        const eventId = info.event.id
        // For recurring event instances, extract the original event ID
        const originalId = info.event.extendedProps?.originalId || eventId
        this.pushEvent("event_clicked", { id: originalId })
      },
      
      // Select date range to create event (admin only)
      select: (info) => {
        if (this.isAdmin) {
          this.pushEvent("date_range_selected", {
            start: info.startStr,
            end: info.endStr,
            allDay: false  // Always default to timed event, not all-day
          })
        }
      },
      
      // Add description and location to list view events
      eventDidMount: (info) => {
        // Only enhance list view events
        if (info.view.type === 'listMonth') {
          const titleEl = info.el.querySelector('.fc-list-event-title')
          if (!titleEl) return
          
          const location = info.event.extendedProps.location
          const description = info.event.extendedProps.description
          
          // Only add details container if we have location or description
          if (location || description) {
            const detailsContainer = document.createElement('div')
            detailsContainer.className = 'fc-list-event-details'
            detailsContainer.style.cssText = `
              margin-top: 6px;
              display: flex;
              flex-direction: column;
              gap: 4px;
            `
            
            // Add location if exists
            if (location) {
              const locationEl = document.createElement('div')
              locationEl.className = 'fc-list-event-location'
              locationEl.innerHTML = `
                <svg style="display: inline-block; width: 14px; height: 14px; margin-right: 6px; vertical-align: middle; color: #06b6d4;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"></path>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"></path>
                </svg>
                <span style="color: #d1d5db; font-size: 0.85rem;">${location}</span>
              `
              locationEl.style.cssText = `
                display: flex;
                align-items: center;
              `
              detailsContainer.appendChild(locationEl)
            }
            
            // Add description if exists
            if (description) {
              const descEl = document.createElement('div')
              descEl.className = 'fc-list-event-description'
              descEl.textContent = description
              descEl.style.cssText = `
                font-size: 0.8rem;
                color: #9ca3af;
                line-height: 1.4;
                max-width: 600px;
                display: -webkit-box;
                -webkit-line-clamp: 2;
                -webkit-box-orient: vertical;
                overflow: hidden;
              `
              detailsContainer.appendChild(descEl)
            }
            
            titleEl.appendChild(detailsContainer)
          }
        }
      }
    })
    
    this.calendar.render()
  },
  
  transformEvent(event) {
    return {
      id: event.id,
      title: event.title,
      start: event.start_time,
      end: event.end_time,
      allDay: event.all_day,
      backgroundColor: event.color,
      borderColor: event.color,
      extendedProps: {
        description: event.description,
        location: event.location,
        eventType: event.event_type,
        isRecurring: event.is_recurring,
        recurrenceRule: event.recurrence_rule,
        recurrenceEndDate: event.recurrence_end_date,
        originalId: event.id
      }
    }
  },
  
  expandRecurringEvents(events, rangeStart, rangeEnd) {
    const expandedEvents = []
    
    events.forEach(event => {
      if (event.extendedProps.isRecurring && event.extendedProps.recurrenceRule) {
        try {
          // Parse the RRULE
          const rruleStr = event.extendedProps.recurrenceRule
          const dtstart = new Date(event.start)
          
          // Build RRULE options
          const options = RRule.parseString(rruleStr)
          options.dtstart = dtstart
          
          // Add until date if specified
          if (event.extendedProps.recurrenceEndDate) {
            options.until = new Date(event.extendedProps.recurrenceEndDate)
          }
          
          const rule = new RRule(options)
          
          // Get occurrences within the visible range
          const occurrences = rule.between(rangeStart, rangeEnd, true)
          
          // Calculate duration
          const originalStart = new Date(event.start)
          const originalEnd = new Date(event.end)
          const duration = originalEnd - originalStart
          
          occurrences.forEach((occurrence, index) => {
            const occurrenceEnd = new Date(occurrence.getTime() + duration)
            expandedEvents.push({
              ...event,
              id: `${event.id}_${index}`,
              start: occurrence.toISOString(),
              end: occurrenceEnd.toISOString(),
              extendedProps: {
                ...event.extendedProps,
                originalId: event.id,
                isInstance: true
              }
            })
          })
        } catch (e) {
          console.error("Error expanding recurring event:", e)
          // Fall back to showing the original event
          expandedEvents.push(event)
        }
      } else {
        expandedEvents.push(event)
      }
    })
    
    return expandedEvents
  },
  
  updateEvents(events) {
    // Remove all events and add new ones
    this.calendar.removeAllEvents()
    events.forEach(event => {
      this.calendar.addEvent(this.transformEvent(event))
    })
  },
  
  // Public methods to be called from LiveView
  changeView(viewName) {
    this.calendar.changeView(viewName)
  },
  
  today() {
    this.calendar.today()
  },
  
  prev() {
    this.calendar.prev()
  },
  
  next() {
    this.calendar.next()
  },
  
  getTitle() {
    return this.calendar.view.title
  },
  
  destroyed() {
    if (this.calendar) {
      this.calendar.destroy()
    }
  },
  
  updated() {
    // Handle view change commands from LiveView
    const viewCommand = this.el.dataset.viewCommand
    if (viewCommand && viewCommand !== '' && viewCommand !== 'null') {
      let commandExecuted = true
      switch(viewCommand) {
        case 'month':
          this.calendar.changeView('dayGridMonth')
          break
        case 'list':
          this.calendar.changeView('listMonth')
          break
        case 'today':
          this.calendar.today()
          break
        case 'prev':
          this.calendar.prev()
          break
        case 'next':
          this.calendar.next()
          break
        default:
          commandExecuted = false
      }
      
      if (commandExecuted) {
        // Push updated title back to LiveView
        this.pushEvent("calendar_navigated", { title: this.calendar.view.title })
      }
      // Clear the command (always clear to prevent repeated execution)
      this.el.dataset.viewCommand = ''
    }
  }
}

// PrintCalendar Hook - handles print preview generation and printing
const PrintCalendar = {
  mounted() {
    // Handle iCal download (merged from IcalDownload hook)
    this.handleEvent("download_ical", ({content, filename}) => {
      const blob = new Blob([content], { type: "text/calendar;charset=utf-8;" })
      const link = document.createElement("a")
      const url = URL.createObjectURL(blob)
      link.setAttribute("href", url)
      link.setAttribute("download", filename)
      link.style.visibility = "hidden"
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
    })
    
    // Handle print preview using new window for proper multi-page support
    this.handleEvent("show_print_preview", ({html}) => {
      // Build the full HTML document
      const printDocument = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Print Calendar</title>
          <style>
            /* Force all elements to be visible */
            *, *::before, *::after {
              box-sizing: border-box;
              visibility: visible !important;
            }
            html, body {
              font-family: Arial, sans-serif;
              margin: 0;
              padding: 20px;
              background: #ffffff !important;
              color: #000000 !important;
              width: 100%;
              height: auto;
            }
            @media print {
              html, body {
                padding: 0;
                margin: 0;
                background: #ffffff !important;
              }
              * {
                visibility: visible !important;
                -webkit-print-color-adjust: exact !important;
                print-color-adjust: exact !important;
              }
              @page {
                size: portrait;
                margin: 0.5in;
              }
            }
            /* Grid layout styles */
            .print-grid, .print-agenda {
              width: 100%;
              background: #ffffff;
              color: #000000;
            }
            .month-grid {
              page-break-inside: avoid;
              margin-bottom: 30px;
            }
            .calendar-grid {
              border: 1px solid #cccccc;
            }
            .day-headers {
              display: grid !important;
              grid-template-columns: repeat(7, 1fr);
              background: #f5f5f5;
              border-bottom: 1px solid #cccccc;
            }
            .day-header {
              padding: 8px 4px;
              text-align: center;
              font-weight: bold;
              font-size: 12px;
              border-right: 1px solid #cccccc;
              color: #333333;
            }
            .day-header:last-child {
              border-right: none;
            }
            .calendar-week {
              display: grid !important;
              grid-template-columns: repeat(7, 1fr);
              border-bottom: 1px solid #cccccc;
            }
            .calendar-week:last-child {
              border-bottom: none;
            }
            .calendar-day {
              min-height: 80px;
              padding: 4px;
              border-right: 1px solid #cccccc;
              vertical-align: top;
              background: #ffffff;
            }
            .calendar-day:last-child {
              border-right: none;
            }
            .calendar-day.empty {
              background: #f9f9f9;
            }
            .day-number {
              font-weight: bold;
              font-size: 14px;
              margin-bottom: 4px;
              color: #000000;
            }
            .day-event {
              font-size: 10px;
              padding: 2px 4px;
              margin-bottom: 2px;
              border-radius: 2px;
              color: #ffffff;
              overflow: hidden;
              text-overflow: ellipsis;
              white-space: nowrap;
            }
            .day-events {
              display: flex !important;
              flex-direction: column;
              gap: 2px;
            }
            /* Agenda layout styles */
            .agenda-content {
              display: flex !important;
              flex-direction: column;
            }
            .agenda-day {
              margin-bottom: 20px;
              page-break-inside: avoid;
            }
            .agenda-events {
              display: flex !important;
              flex-direction: column;
              gap: 8px;
            }
            .agenda-event {
              display: flex !important;
              gap: 12px;
              padding: 12px;
              border: 1px solid #dddddd;
              border-radius: 4px;
              background: #ffffff;
            }
            /* Grid content */
            .grid-content {
              display: flex !important;
              flex-direction: column;
              gap: 32px;
            }
            .calendar-days {
              display: block !important;
            }
            /* Headers */
            .print-header {
              text-align: center;
              margin-bottom: 24px;
              padding-bottom: 16px;
              border-bottom: 3px double #333333;
            }
            .print-header h1 {
              font-size: 28px;
              font-weight: bold;
              margin: 0 0 4px 0;
              color: #000000;
            }
            .month-title {
              font-size: 20px;
              font-weight: bold;
              color: #000000;
              margin: 0 0 16px 0;
              padding-bottom: 8px;
              border-bottom: 2px solid #333333;
            }
          </style>
        </head>
        <body>
          ${html}
        </body>
        </html>
      `
      
      // Open new window for printing (more reliable than iframe)
      const printWindow = window.open('', '_blank', 'width=800,height=600')
      if (printWindow) {
        printWindow.document.open()
        printWindow.document.write(printDocument)
        printWindow.document.close()
        
        // Wait for content to render, then print
        setTimeout(() => {
          printWindow.focus()
          printWindow.print()
          
          // Close the window after printing
          printWindow.onafterprint = () => {
            printWindow.close()
          }
          
          // Fallback: close after a delay if onafterprint doesn't fire
          setTimeout(() => {
            if (!printWindow.closed) {
              printWindow.close()
            }
          }, 60000) // Close after 60 seconds if still open
        }, 500)
      } else {
        alert('Please allow popups to print the calendar')
      }
    })
  },
  
  destroyed() {
    // No cleanup needed for new window approach
  }
}

// IcalDownload Hook - handles iCal file download from LiveView events (kept for backwards compatibility)
const IcalDownload = {
  mounted() {
    this.handleEvent("download_ical", ({content, filename}) => {
      const blob = new Blob([content], { type: "text/calendar;charset=utf-8;" })
      const link = document.createElement("a")
      const url = URL.createObjectURL(blob)
      link.setAttribute("href", url)
      link.setAttribute("download", filename)
      link.style.visibility = "hidden"
      document.body.appendChild(link)
      link.click()
      document.body.removeChild(link)
      URL.revokeObjectURL(url)
    })
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, MobileMenu, ThemeDropdown, PhoneFormat, ImageUpload, AutoFocus, DatePicker, DatePickerClose, DateTimeInput, LocalTime, CsvDownload, BarChart, PieChart, DoughnutChart, EventCalendar, IcalDownload, PrintCalendar, ModalPortal},
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

