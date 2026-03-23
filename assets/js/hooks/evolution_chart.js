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

    this.handleEvent('update-chart', ({dates, data, view_mode}) => {
      this.updateChart(dates, data, view_mode)
    })

    // Notify LiveView that chart is ready
    this.pushEvent('chart-mounted', {})
  },

  updated() {
    const dates = JSON.parse(this.el.dataset.dates || '[]')
    const data = JSON.parse(this.el.dataset.data || '{}')
    const viewMode = this.el.dataset.viewMode || 'overall'

    if (dates.length > 0 && this.chart) {
      this.updateChart(dates, data, viewMode)
    }
  },

  updateChart(dates, data, viewMode) {
    if (!this.chart) return

    this.chart.data.labels = dates

    if (viewMode === 'overall') {
      this.chart.data.datasets = this.buildOverallDatasets(data)
    } else {
      this.chart.data.datasets = this.buildPerProviderDatasets(data)
    }

    this.chart.update()
  },

  buildOverallDatasets(data) {
    return [
      {
        label: 'Pass Rate',
        data: data.overall_pass_rates || [],
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.2)',
        yAxisID: 'y-pass-rate',
        tension: 0.1
      },
      {
        label: 'Executions',
        data: data.overall_executions || [],
        borderColor: 'rgb(54, 162, 235)',
        backgroundColor: 'rgba(54, 162, 235, 0.2)',
        yAxisID: 'y-executions',
        tension: 0.1
      },
      {
        label: 'Failures',
        data: data.overall_failures || [],
        borderColor: 'rgb(255, 99, 132)',
        backgroundColor: 'rgba(255, 99, 132, 0.2)',
        yAxisID: 'y-failures',
        tension: 0.1
      }
    ]
  },

  buildPerProviderDatasets(data) {
    const datasets = []
    const providers = data.providers || []

    providers.forEach((provider, index) => {
      const colors = this.getProviderColors(index)

      datasets.push(
        {
          label: `${provider} - Pass Rate`,
          data: data[`${provider}_pass_rates`] || [],
          borderColor: colors.passRate,
          backgroundColor: colors.passRateBg,
          yAxisID: 'y-pass-rate',
          tension: 0.1
        },
        {
          label: `${provider} - Executions`,
          data: data[`${provider}_executions`] || [],
          borderColor: colors.executions,
          backgroundColor: colors.executionsBg,
          yAxisID: 'y-executions',
          tension: 0.1
        },
        {
          label: `${provider} - Failures`,
          data: data[`${provider}_failures`] || [],
          borderColor: colors.failures,
          backgroundColor: colors.failuresBg,
          yAxisID: 'y-failures',
          tension: 0.1
        }
      )
    })

    return datasets
  },

  getProviderColors(index) {
    const colorSets = [
      {
        passRate: 'rgb(75, 192, 192)',
        passRateBg: 'rgba(75, 192, 192, 0.2)',
        executions: 'rgb(54, 162, 235)',
        executionsBg: 'rgba(54, 162, 235, 0.2)',
        failures: 'rgb(255, 99, 132)',
        failuresBg: 'rgba(255, 99, 132, 0.2)'
      },
      {
        passRate: 'rgb(153, 102, 255)',
        passRateBg: 'rgba(153, 102, 255, 0.2)',
        executions: 'rgb(255, 159, 64)',
        executionsBg: 'rgba(255, 159, 64, 0.2)',
        failures: 'rgb(255, 205, 86)',
        failuresBg: 'rgba(255, 205, 86, 0.2)'
      },
      {
        passRate: 'rgb(201, 203, 207)',
        passRateBg: 'rgba(201, 203, 207, 0.2)',
        executions: 'rgb(83, 102, 255)',
        executionsBg: 'rgba(83, 102, 255, 0.2)',
        failures: 'rgb(255, 102, 196)',
        failuresBg: 'rgba(255, 102, 196, 0.2)'
      }
    ]

    return colorSets[index % colorSets.length]
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
        title: {
          display: true,
          text: 'Test Execution Trends'
        }
      },
      scales: {
        x: {
          display: true,
          title: {
            display: true,
            text: 'Date'
          }
        },
        'y-pass-rate': {
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
        'y-executions': {
          type: 'linear',
          display: true,
          position: 'right',
          title: {
            display: true,
            text: 'Executions'
          },
          grid: {
            drawOnChartArea: false
          }
        },
        'y-failures': {
          type: 'linear',
          display: true,
          position: 'right',
          title: {
            display: true,
            text: 'Failures'
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
