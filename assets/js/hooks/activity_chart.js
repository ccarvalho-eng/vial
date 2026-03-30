export const ActivityChart = {
  mounted() {
    this.initTooltip()
  },
  updated() {
    this.initTooltip()
  },
  initTooltip() {
    const container = this.el.querySelector('#activity-bars')
    const tooltip = this.el.querySelector('#activity-tooltip')
    const tooltipContent = this.el.querySelector('#tooltip-content')

    if (!container || !tooltip || !tooltipContent) return

    // Remove old listeners
    if (this.mouseoverHandler) {
      container.removeEventListener('mouseover', this.mouseoverHandler)
    }
    if (this.mouseoutHandler) {
      container.removeEventListener('mouseout', this.mouseoutHandler)
    }

    // Create new handlers
    this.mouseoverHandler = (e) => {
      if (e.target.classList.contains('activity-bar')) {
        const date = e.target.dataset.date
        const total = e.target.dataset.total
        const runs = total == 1 ? 'run' : 'runs'

        tooltipContent.innerHTML = `<strong>${date}</strong><br>${total} ${runs}`

        const rect = e.target.getBoundingClientRect()
        const containerRect = container.getBoundingClientRect()
        const left = rect.left - containerRect.left + (rect.width / 2)

        tooltip.style.left = left + 'px'
        tooltip.style.opacity = '1'

        e.target.style.transform = 'scaleY(1.05)'
        e.target.style.opacity = '1'
      }
    }

    this.mouseoutHandler = (e) => {
      if (e.target.classList.contains('activity-bar')) {
        tooltip.style.opacity = '0'
        e.target.style.transform = 'scaleY(1)'
        // Reset opacity based on computed style rather than checking inline
        const computedOpacity = window.getComputedStyle(e.target).opacity
        if (computedOpacity !== '1') {
          e.target.style.opacity = computedOpacity
        }
      }
    }

    // Attach new listeners
    container.addEventListener('mouseover', this.mouseoverHandler)
    container.addEventListener('mouseout', this.mouseoutHandler)
  },
  destroyed() {
    const container = this.el.querySelector('#activity-bars')
    if (container && this.mouseoverHandler) {
      container.removeEventListener('mouseover', this.mouseoverHandler)
    }
    if (container && this.mouseoutHandler) {
      container.removeEventListener('mouseout', this.mouseoutHandler)
    }
  }
}