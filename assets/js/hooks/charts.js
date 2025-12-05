// Chart.js Hooks for Phoenix LiveView
// This file contains hooks for rendering interactive charts with Chart.js

// We'll use a CDN-loaded Chart.js for now since npm is not available
// The Chart.js library will be loaded via script tag in root.html.heex

// Extended color palette for many data points (30+ colors)
const colorPalette = [
  { bg: 'rgba(6, 182, 212, 0.8)', border: 'rgba(6, 182, 212, 1)' },     // Cyan
  { bg: 'rgba(34, 197, 94, 0.8)', border: 'rgba(34, 197, 94, 1)' },     // Green
  { bg: 'rgba(251, 191, 36, 0.8)', border: 'rgba(251, 191, 36, 1)' },   // Yellow/Amber
  { bg: 'rgba(239, 68, 68, 0.8)', border: 'rgba(239, 68, 68, 1)' },     // Red
  { bg: 'rgba(168, 85, 247, 0.8)', border: 'rgba(168, 85, 247, 1)' },   // Purple
  { bg: 'rgba(236, 72, 153, 0.8)', border: 'rgba(236, 72, 153, 1)' },   // Pink
  { bg: 'rgba(59, 130, 246, 0.8)', border: 'rgba(59, 130, 246, 1)' },   // Blue
  { bg: 'rgba(249, 115, 22, 0.8)', border: 'rgba(249, 115, 22, 1)' },   // Orange
  { bg: 'rgba(20, 184, 166, 0.8)', border: 'rgba(20, 184, 166, 1)' },   // Teal
  { bg: 'rgba(244, 63, 94, 0.8)', border: 'rgba(244, 63, 94, 1)' },     // Rose
  { bg: 'rgba(139, 92, 246, 0.8)', border: 'rgba(139, 92, 246, 1)' },   // Violet
  { bg: 'rgba(14, 165, 233, 0.8)', border: 'rgba(14, 165, 233, 1)' },   // Sky
  { bg: 'rgba(16, 185, 129, 0.8)', border: 'rgba(16, 185, 129, 1)' },   // Emerald
  { bg: 'rgba(245, 158, 11, 0.8)', border: 'rgba(245, 158, 11, 1)' },   // Amber
  { bg: 'rgba(99, 102, 241, 0.8)', border: 'rgba(99, 102, 241, 1)' },   // Indigo
  { bg: 'rgba(217, 70, 239, 0.8)', border: 'rgba(217, 70, 239, 1)' },   // Fuchsia
  { bg: 'rgba(132, 204, 22, 0.8)', border: 'rgba(132, 204, 22, 1)' },   // Lime
  { bg: 'rgba(234, 88, 12, 0.8)', border: 'rgba(234, 88, 12, 1)' },     // Orange-600
  { bg: 'rgba(79, 70, 229, 0.8)', border: 'rgba(79, 70, 229, 1)' },     // Indigo-600
  { bg: 'rgba(192, 38, 211, 0.8)', border: 'rgba(192, 38, 211, 1)' },   // Fuchsia-600
  { bg: 'rgba(5, 150, 105, 0.8)', border: 'rgba(5, 150, 105, 1)' },     // Emerald-600
  { bg: 'rgba(202, 138, 4, 0.8)', border: 'rgba(202, 138, 4, 1)' },     // Yellow-600
  { bg: 'rgba(220, 38, 38, 0.8)', border: 'rgba(220, 38, 38, 1)' },     // Red-600
  { bg: 'rgba(37, 99, 235, 0.8)', border: 'rgba(37, 99, 235, 1)' },     // Blue-600
  { bg: 'rgba(13, 148, 136, 0.8)', border: 'rgba(13, 148, 136, 1)' },   // Teal-600
  { bg: 'rgba(147, 51, 234, 0.8)', border: 'rgba(147, 51, 234, 1)' },   // Purple-600
  { bg: 'rgba(219, 39, 119, 0.8)', border: 'rgba(219, 39, 119, 1)' },   // Pink-600
  { bg: 'rgba(101, 163, 13, 0.8)', border: 'rgba(101, 163, 13, 1)' },   // Lime-600
  { bg: 'rgba(8, 145, 178, 0.8)', border: 'rgba(8, 145, 178, 1)' },     // Cyan-600
  { bg: 'rgba(124, 58, 237, 0.8)', border: 'rgba(124, 58, 237, 1)' },   // Violet-600
]

// Generate colors for any number of data points
function getColors(count, opacity = 0.8) {
  const bgColors = []
  const borderColors = []
  
  for (let i = 0; i < count; i++) {
    const colorIndex = i % colorPalette.length
    bgColors.push(colorPalette[colorIndex].bg.replace('0.8', String(opacity)))
    borderColors.push(colorPalette[colorIndex].border)
  }
  
  return { background: bgColors, border: borderColors }
}

// Dark theme color palette
const darkTheme = {
  text: '#f3f4f6',
  grid: 'rgba(64, 64, 64, 0.3)',
  gridBorder: 'rgba(64, 64, 64, 0.5)'
}

// Light theme color palette
const lightTheme = {
  text: '#111827',
  grid: 'rgba(209, 213, 219, 0.5)',
  gridBorder: 'rgba(209, 213, 219, 1)'
}

// Get current theme
function getCurrentTheme() {
  const theme = document.documentElement.getAttribute('data-theme')
  return theme === 'light' ? lightTheme : darkTheme
}

// Common chart options
function getCommonOptions(title) {
  const theme = getCurrentTheme()
  
  return {
    responsive: true,
    maintainAspectRatio: true,
    plugins: {
      legend: {
        position: 'bottom',
        labels: {
          color: theme.text,
          padding: 15,
          font: {
            size: 12
          }
        }
      },
      title: {
        display: false
      },
      tooltip: {
        backgroundColor: 'rgba(0, 0, 0, 0.8)',
        titleColor: '#fff',
        bodyColor: '#fff',
        borderColor: colorPalette[0].border,
        borderWidth: 1,
        padding: 12,
        displayColors: true,
        callbacks: {}
      }
    }
  }
}

// Bar Chart Hook
export const BarChart = {
  mounted() {
    this.initChart()
  },

  updated() {
    this.updateChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  initChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')
    const title = this.el.dataset.chartTitle || 'Chart'
    const horizontal = this.el.dataset.chartHorizontal === 'true'
    const isCurrency = this.el.dataset.chartCurrency === 'true'
    const theme = getCurrentTheme()

    const labels = data.map(item => item.label)
    const values = data.map(item => item.value)
    
    // Get colors for the number of data points
    const colors = getColors(data.length)

    const options = getCommonOptions(title)
    
    // Configure for horizontal or vertical
    if (horizontal) {
      options.indexAxis = 'y'
      options.scales = {
        x: {
          grid: {
            color: theme.grid,
            borderColor: theme.gridBorder
          },
          ticks: {
            color: theme.text,
            callback: function(value) {
              return isCurrency ? '$' + value.toLocaleString() : value
            }
          }
        },
        y: {
          grid: {
            display: false
          },
          ticks: {
            color: theme.text
          }
        }
      }
    } else {
      options.scales = {
        y: {
          beginAtZero: true,
          grid: {
            color: theme.grid,
            borderColor: theme.gridBorder
          },
          ticks: {
            color: theme.text,
            callback: function(value) {
              return isCurrency ? '$' + value.toLocaleString() : value
            }
          }
        },
        x: {
          grid: {
            display: false
          },
          ticks: {
            color: theme.text
          }
        }
      }
    }

    // Currency formatting in tooltips
    if (isCurrency) {
      options.plugins.tooltip.callbacks.label = function(context) {
        const value = horizontal ? context.parsed.x : context.parsed.y
        return context.dataset.label + ': $' + value.toLocaleString()
      }
    }

    const config = {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: title,
          data: values,
          backgroundColor: colors.background,
          borderColor: colors.border,
          borderWidth: 2
        }]
      },
      options: options
    }

    this.chart = new Chart(this.el, config)
  },

  updateChart() {
    if (this.chart) {
      this.chart.destroy()
    }
    this.initChart()
  }
}

// Pie Chart Hook
export const PieChart = {
  mounted() {
    this.initChart()
  },

  updated() {
    this.updateChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  initChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')
    const title = this.el.dataset.chartTitle || 'Chart'
    const theme = getCurrentTheme()

    const labels = data.map(item => item.label)
    const values = data.map(item => item.value)
    
    // Get colors for the number of data points
    const colors = getColors(data.length)

    const options = getCommonOptions(title)
    
    // Add percentage display in tooltips
    options.plugins.tooltip.callbacks.label = function(context) {
      const label = context.label || ''
      const value = context.parsed || 0
      const total = context.dataset.data.reduce((a, b) => a + b, 0)
      const percentage = ((value / total) * 100).toFixed(1)
      return label + ': ' + value + ' (' + percentage + '%)'
    }

    const config = {
      type: 'pie',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors.background,
          borderColor: colors.border,
          borderWidth: 2
        }]
      },
      options: options
    }

    this.chart = new Chart(this.el, config)
  },

  updateChart() {
    if (this.chart) {
      this.chart.destroy()
    }
    this.initChart()
  }
}

// Doughnut Chart Hook
export const DoughnutChart = {
  mounted() {
    this.initChart()
  },

  updated() {
    this.updateChart()
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
    }
  },

  initChart() {
    const data = JSON.parse(this.el.dataset.chartData || '[]')
    const title = this.el.dataset.chartTitle || 'Chart'
    const theme = getCurrentTheme()

    const labels = data.map(item => item.label)
    const values = data.map(item => item.value)
    
    // Get colors for the number of data points
    const colors = getColors(data.length)

    const options = getCommonOptions(title)
    
    // Add percentage display in tooltips
    options.plugins.tooltip.callbacks.label = function(context) {
      const label = context.label || ''
      const value = context.parsed || 0
      const total = context.dataset.data.reduce((a, b) => a + b, 0)
      const percentage = ((value / total) * 100).toFixed(1)
      return label + ': ' + value + ' (' + percentage + '%)'
    }

    const config = {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: colors.background,
          borderColor: colors.border,
          borderWidth: 2
        }]
      },
      options: options
    }

    this.chart = new Chart(this.el, config)
  },

  updateChart() {
    if (this.chart) {
      this.chart.destroy()
    }
    this.initChart()
  }
}