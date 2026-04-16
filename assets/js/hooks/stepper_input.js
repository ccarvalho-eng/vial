export const StepperInput = {
  mounted() {
    this.input = this.el.querySelector("[data-stepper-input]")
    this.buttons = Array.from(this.el.querySelectorAll("[data-stepper-direction]"))
    this.step = parseFloat(this.el.dataset.step || "1") || 1
    this.min = this.parseMin(this.el.dataset.min)
    this.precision = this.decimalPlaces(this.el.dataset.step || "1")

    this.handleClick = (event) => {
      const button = event.currentTarget
      const direction = button.dataset.stepperDirection

      if (!this.input || this.input.disabled) {
        return
      }

      const current = this.parseCurrentValue()
      const delta = direction === "increment" ? this.step : -this.step
      let nextValue = current + delta

      if (this.min !== null) {
        nextValue = Math.max(this.min, nextValue)
      }

      this.input.value = this.formatValue(nextValue)
      this.input.dispatchEvent(new Event("input", {bubbles: true}))
      this.input.dispatchEvent(new Event("change", {bubbles: true}))
      this.input.focus()
    }

    this.buttons.forEach((button) => button.addEventListener("click", this.handleClick))
  },

  destroyed() {
    this.buttons?.forEach((button) => button.removeEventListener("click", this.handleClick))
  },

  parseCurrentValue() {
    const parsed = parseFloat(this.input.value)

    if (!Number.isNaN(parsed)) {
      return parsed
    }

    return this.min !== null ? this.min : 0
  },

  parseMin(value) {
    if (value === undefined || value === null || value === "") {
      return null
    }

    const parsed = parseFloat(value)
    return Number.isNaN(parsed) ? null : parsed
  },

  decimalPlaces(step) {
    const normalized = String(step)
    const decimals = normalized.split(".")[1]
    return decimals ? decimals.length : 0
  },

  formatValue(value) {
    if (this.precision === 0) {
      return `${Math.round(value)}`
    }

    return value.toFixed(this.precision)
  }
}
