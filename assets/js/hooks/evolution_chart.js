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
    const canvas = this.el.querySelector('canvas')
    if (!canvas) return

    this.chart = new Chart(canvas, {
      type: 'line',
      data: {
        labels: [],
        datasets: []
      },
      options: this.getChartOptions()
    })

    this.handleEvent('update-chart', ({chart_data, view_mode}) => {
      this.updateChart(chart_data, view_mode)
    })

    // Trigger initial data load
    this.pushEvent('chart-mounted', {})
  },

  updated() {
    const chartData = JSON.parse(this.el.dataset.chartData || '{}')
    const viewMode = this.el.dataset.viewMode || 'overall'

    if (Object.keys(chartData).length > 0 && this.chart) {
      this.updateChart(chartData, viewMode)
    }
  },

  updateChart(chartData, viewMode) {
    if (!this.chart || !chartData.versions) return

    const datasets = viewMode === 'overall'
      ? this.buildOverallDatasets(chartData)
      : this.buildPerProviderDatasets(chartData)

    this.chart.data.labels = chartData.versions.map(v => `v${v}`)
    this.chart.data.datasets = datasets

    // Update scale visibility based on data
    this.updateScales(chartData, viewMode)

    this.chart.update() // Full update with recalculation
  },

  updateScales(chartData, viewMode) {
    if (viewMode === 'overall') {
      const hasCost = chartData.overall.costs && chartData.overall.costs.some(c => c !== null)
      const hasLatency = chartData.overall.latencies && chartData.overall.latencies.some(l => l !== null)

      this.chart.options.scales.y.display = true
      this.chart.options.scales.y1.display = hasCost
      this.chart.options.scales.y2.display = hasLatency
    } else {
      // Per-provider only shows pass rate
      this.chart.options.scales.y.display = true
      this.chart.options.scales.y1.display = false
      this.chart.options.scales.y2.display = false
    }
  },

  buildOverallDatasets(chartData) {
    return [
      {
        label: 'Pass Rate',
        data: chartData.overall.pass_rates,
        borderColor: '#10b981',
        backgroundColor: 'rgba(16, 185, 129, 0.1)',
        yAxisID: 'y',
        tension: 0.3
      },
      {
        label: 'Cost',
        data: chartData.overall.costs,
        borderColor: '#f59e0b',
        backgroundColor: 'rgba(245, 158, 11, 0.1)',
        yAxisID: 'y1',
        tension: 0.3
      },
      {
        label: 'Latency',
        data: chartData.overall.latencies,
        borderColor: '#3b82f6',
        backgroundColor: 'rgba(59, 130, 246, 0.1)',
        yAxisID: 'y2',
        tension: 0.3
      }
    ]
  },

  buildPerProviderDatasets(chartData) {
    const datasets = []
    const colors = [
      '#10b981', '#3b82f6', '#f59e0b', '#ef4444',
      '#8b5cf6', '#ec4899', '#14b8a6', '#f97316'
    ]

    let colorIndex = 0

    Object.entries(chartData.by_provider || {}).forEach(([providerName, data]) => {
      const color = colors[colorIndex % colors.length]

      datasets.push({
        label: `${providerName} - Pass Rate`,
        data: data.pass_rates,
        borderColor: color,
        backgroundColor: `${color}33`,
        yAxisID: 'y',
        tension: 0.3
      })

      colorIndex++
    })

    return datasets
  },

  getChartOptions() {
    return {
      responsive: true,
      maintainAspectRatio: false,
      interaction: {
        mode: 'index',
        intersect: false
      },
      plugins: {
        legend: {
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
          position: 'left',
          title: {
            display: true,
            text: 'Pass Rate (%)'
          },
          min: 0,
          max: 100
        },
        y1: {
          type: 'linear',
          display: true,
          position: 'right',
          title: {
            display: true,
            text: 'Cost ($)'
          },
          grid: {
            drawOnChartArea: false
          }
        },
        y2: {
          type: 'linear',
          display: true,
          position: 'right',
          title: {
            display: true,
            text: 'Latency (ms)'
          },
          grid: {
            drawOnChartArea: false
          }
        }
      }
    }
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }
}
