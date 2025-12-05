// Chart.js Hooks for Phoenix LiveView
// This file contains hooks for rendering interactive charts with Chart.js

// We'll use a CDN-loaded Chart.js for now since npm is not available
// The Chart.js library will be loaded via script tag in root.html.heex

// Dark theme color palette
const darkTheme = {
  background: [
    'rgba(6, 182, 212, 0.8)',   // Primary cyan
    'rgba(34, 197, 94, 0.8)',   // Green
    'rgba(251, 191, 36, 0.8)',  // Yellow/Amber
    'rgba(239, 68, 68, 0.8)',   // Red
    'rgba(168, 85, 247, 0.8)',  // Purple/Violet
    'rgba(236, 72, 153, 0.8)',  // Pink
    'rgba(59, 130, 246, 0.8)',  // Blue
    'rgba(249, 115, 22, 0.8)',  // Orange
    'rgba(20, 184, 166, 0.8)',  // Teal
    'rgba(244, 63, 94, 0.8)',   // Rose
    'rgba(139, 92, 246, 0.8)',  // Violet
    'rgba(14, 165, 233, 0.8)',  // Sky
  ],
  border: [
    'rgba(6, 182, 212, 1)',
    'rgba(34, 197, 94, 1)',
    'rgba(251, 191, 36, 1)',
    'rgba(239, 68, 68, 1)',
    'rgba(168, 85, 247, 1)',
    'rgba(236, 72, 153, 1)',
    'rgba(59, 130, 246, 1)',
    'rgba(249, 115, 22, 1)',
    'rgba(20, 184, 166, 1)',
    'rgba(244, 63, 94, 1)',
    'rgba(139, 92, 246, 1)',
    'rgba(14, 165, 233, 1)',
  ],
  text: '#f3f4f6',
  grid: 'rgba(64, 64, 64, 0.3)',
  gridBorder: 'rgba(64, 64, 64, 0.5)'
}

// Light theme color palette
const lightTheme = {
  background: [
    'rgba(6, 182, 212, 0.6)',
    'rgba(34, 197, 94, 0.6)',
    'rgba(251, 191, 36, 0.6)',
    'rgba(239, 68, 68, 0.6)',
    'rgba(168, 85, 247, 0.6)',
    'rgba(236, 72, 153, 0.6)',
    'rgba(59, 130, 246, 0.6)',
    'rgba(249, 115, 22, 0.6)',
    'rgba(20, 184, 166, 0.6)',
    'rgba(244, 63, 94, 0.6)',
    'rgba(139, 92, 246, 0.6)',
    'rgba(14, 165, 233, 0.6)',
  ],
  border: [
    'rgba(6, 182, 212, 1)',
    'rgba(34, 197, 94, 1)',
    'rgba(251, 191, 36, 1)',
    'rgba(239, 68, 68, 1)',
    'rgba(168, 85, 247, 1)',
    'rgba(236, 72, 153, 1)',
    'rgba(59, 130, 246, 1)',
    'rgba(249, 115, 22, 1)',
    'rgba(20, 184, 166, 1)',
    'rgba(244, 63, 94, 1)',
    'rgba(139, 92, 246, 1)',
    'rgba(14, 165, 233, 1)',
  ],
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
        borderColor: theme.border[0],
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
        return context.dataset.label + ': $' + context.parsed.y.toLocaleString()
      }
    }

    const config = {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: title,
          data: values,
          backgroundColor: theme.background,
          borderColor: theme.border,
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
          backgroundColor: theme.background,
          borderColor: theme.border,
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
          backgroundColor: theme.background,
          borderColor: theme.border,
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