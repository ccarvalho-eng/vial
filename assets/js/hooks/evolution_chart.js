import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Title,
  Tooltip,
  Legend,
  CategoryScale
} from 'chart.js'

Chart.register(
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  Title,
  Tooltip,
  Legend,
  CategoryScale
)

export const EvolutionChart = {
  mounted() {
    this.charts = {}
    this.createCharts()

    this.handleEvent('update-chart', ({chart_data, view_mode}) => {
      this.updateCharts(chart_data, view_mode)
    })

    // Trigger initial data load
    this.pushEvent('chart-mounted', {})
  },

  updated() {
    const chartData = JSON.parse(this.el.dataset.chartData || '{}')
    const viewMode = this.el.dataset.viewMode || 'overall'

    if (Object.keys(chartData).length > 0) {
      this.updateCharts(chartData, viewMode)
    }
  },

  createCharts() {
    // Pass Rate Chart
    const passRateCanvas = this.el.querySelector('#pass-rate-chart')
    if (passRateCanvas) {
      this.charts.passRate = new Chart(passRateCanvas, {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: this.getChartOptions('Pass Rate (%)', 0, 100)
      })
    }

    // Cost Chart
    const costCanvas = this.el.querySelector('#cost-chart')
    if (costCanvas) {
      this.charts.cost = new Chart(costCanvas, {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: this.getCostChartOptions()
      })
    }

    // Latency Chart
    const latencyCanvas = this.el.querySelector('#latency-chart')
    if (latencyCanvas) {
      this.charts.latency = new Chart(latencyCanvas, {
        type: 'line',
        data: { labels: [], datasets: [] },
        options: this.getChartOptions('Latency (ms)', 0, null)
      })
    }
  },

  updateCharts(chartData, viewMode) {
    if (!chartData.versions) return

    const labels = chartData.versions.map(v => `v${v}`)

    // Update Pass Rate Chart
    if (this.charts.passRate) {
      const passRateDatasets = this.buildPassRateDatasets(chartData, viewMode)
      this.charts.passRate.data.labels = labels
      this.charts.passRate.data.datasets = passRateDatasets
      // Only show legend when there are multiple lines (per-provider mode)
      this.charts.passRate.options.plugins.legend.display = viewMode === 'by_provider'
      this.charts.passRate.update()
    }

    // Update Cost Chart
    if (this.charts.cost) {
      const hasCost = this.hasData(chartData.overall.costs)
      const costContainer = this.el.querySelector('#cost-chart-container')

      // Only show in overall mode for now (per-provider cost not in backend data)
      if (hasCost && viewMode === 'overall') {
        costContainer.style.display = 'block'
        const costDatasets = this.buildCostDatasets(chartData)
        this.charts.cost.data.labels = labels
        this.charts.cost.data.datasets = costDatasets
        this.charts.cost.update()
      } else {
        costContainer.style.display = 'none'
      }
    }

    // Update Latency Chart
    if (this.charts.latency) {
      const hasLatency = this.hasData(chartData.overall.latencies)
      const latencyContainer = this.el.querySelector('#latency-chart-container')

      // Only show in overall mode for now (per-provider latency not in backend data)
      if (hasLatency && viewMode === 'overall') {
        latencyContainer.style.display = 'block'
        const latencyDatasets = this.buildLatencyDatasets(chartData)
        this.charts.latency.data.labels = labels
        this.charts.latency.data.datasets = latencyDatasets
        this.charts.latency.update()
      } else {
        latencyContainer.style.display = 'none'
      }
    }
  },

  buildPassRateDatasets(chartData, viewMode) {
    if (viewMode === 'overall') {
      return [{
        label: 'Pass Rate',
        data: chartData.overall.pass_rates,
        borderColor: '#10b981',
        backgroundColor: 'rgba(16, 185, 129, 0.1)',
        tension: 0.3,
        fill: true
      }]
    } else {
      // Per-provider mode
      const colors = [
        '#10b981', '#3b82f6', '#f59e0b', '#ef4444',
        '#8b5cf6', '#ec4899', '#14b8a6', '#f97316'
      ]

      return Object.entries(chartData.by_provider || {}).map(([providerName, data], index) => ({
        label: providerName,
        data: data.pass_rates,
        borderColor: colors[index % colors.length],
        backgroundColor: `${colors[index % colors.length]}33`,
        tension: 0.3,
        fill: false
      }))
    }
  },

  buildCostDatasets(chartData) {
    return [{
      label: 'Average Cost',
      data: chartData.overall.costs,
      borderColor: '#f59e0b',
      backgroundColor: 'rgba(245, 158, 11, 0.1)',
      tension: 0.3,
      fill: true
    }]
  },

  buildLatencyDatasets(chartData) {
    return [{
      label: 'Average Latency',
      data: chartData.overall.latencies,
      borderColor: '#3b82f6',
      backgroundColor: 'rgba(59, 130, 246, 0.1)',
      tension: 0.3,
      fill: true
    }]
  },

  hasData(arr) {
    return arr && arr.some(v => v !== null && v !== undefined)
  },

  getChartOptions(yAxisLabel, min, max, showLegend = false) {
    const options = {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false
      },
      plugins: {
        legend: {
          display: showLegend,
          position: 'top'
        },
        tooltip: {
          mode: 'index',
          intersect: false
        }
      },
      scales: {
        y: {
          type: 'linear',
          display: true,
          title: {
            display: true,
            text: yAxisLabel
          },
          beginAtZero: true
        }
      }
    }

    if (min !== null && min !== undefined) {
      options.scales.y.min = min
    }
    if (max !== null && max !== undefined) {
      options.scales.y.max = max
    }

    return options
  },

  getCostChartOptions() {
    return {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false
      },
      plugins: {
        legend: {
          display: false
        },
        tooltip: {
          mode: 'index',
          intersect: false,
          callbacks: {
            label: function(context) {
              return `Cost: $${context.parsed.y.toFixed(4)}`
            }
          }
        }
      },
      scales: {
        y: {
          type: 'linear',
          display: true,
          title: {
            display: true,
            text: 'Cost ($)'
          },
          beginAtZero: true,
          ticks: {
            callback: function(value) {
              return '$' + value.toFixed(4)
            }
          }
        }
      }
    }
  },

  destroyed() {
    Object.values(this.charts).forEach(chart => {
      if (chart) chart.destroy()
    })
    this.charts = {}
  }
}
