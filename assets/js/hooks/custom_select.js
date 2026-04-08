export const CustomSelect = {
  mounted() {
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    this.handleButtonClick = this.handleButtonClick.bind(this)
    this.handleKeydown = this.handleKeydown.bind(this)
    this.handleOptionClick = this.handleOptionClick.bind(this)

    this.cacheElements()
    this.bindEvents()
    this.syncFromInput()
  },

  updated() {
    this.button?.removeEventListener("click", this.handleButtonClick)
    this.button?.removeEventListener("keydown", this.handleKeydown)
    this.unbindOptionEvents()
    this.cacheElements()
    this.button?.addEventListener("click", this.handleButtonClick)
    this.button?.addEventListener("keydown", this.handleKeydown)
    this.bindOptionEvents()
    this.syncFromInput()
  },

  destroyed() {
    document.removeEventListener("click", this.handleDocumentClick)
    this.button?.removeEventListener("click", this.handleButtonClick)
    this.button?.removeEventListener("keydown", this.handleKeydown)
    this.unbindOptionEvents()
  },

  cacheElements() {
    this.input = this.el.querySelector("[data-select-input]")
    this.button = this.el.querySelector("[data-select-trigger]")
    this.dropdown = this.el.querySelector("[data-select-dropdown]")
    this.valueLabel = this.el.querySelector("[data-select-value]")
    this.options = Array.from(this.el.querySelectorAll("[data-select-option]"))
    this.activeIndex = this.selectedIndex()
  },

  bindEvents() {
    document.addEventListener("click", this.handleDocumentClick)
    this.button?.addEventListener("click", this.handleButtonClick)
    this.button?.addEventListener("keydown", this.handleKeydown)
    this.bindOptionEvents()
  },

  bindOptionEvents() {
    this.options.forEach((option) => option.addEventListener("click", this.handleOptionClick))
  },

  unbindOptionEvents() {
    this.options?.forEach((option) => option.removeEventListener("click", this.handleOptionClick))
  },

  handleDocumentClick(event) {
    if (!this.el.contains(event.target)) {
      this.close()
    }
  },

  handleButtonClick() {
    if (this.isDisabled()) {
      return
    }

    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  },

  handleKeydown(event) {
    if (this.isDisabled()) {
      return
    }

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.moveActive(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.moveActive(-1)
        break
      case "Home":
        event.preventDefault()
        this.open()
        this.setActive(0)
        break
      case "End":
        event.preventDefault()
        this.open()
        this.setActive(this.options.length - 1)
        break
      case "Enter":
      case " ":
        event.preventDefault()
        if (!this.isOpen()) {
          this.open()
        } else if (this.activeIndex >= 0) {
          this.selectOption(this.options[this.activeIndex])
        }
        break
      case "Escape":
        if (this.isOpen()) {
          event.preventDefault()
          this.close()
        }
        break
      case "Tab":
        this.close()
        break
    }
  },

  handleOptionClick(event) {
    event.preventDefault()
    this.selectOption(event.currentTarget)
  },

  isDisabled() {
    return this.input?.disabled || this.button?.disabled
  },

  isOpen() {
    return !!this.dropdown && !this.dropdown.classList.contains("hidden")
  },

  open() {
    if (!this.dropdown || this.options.length === 0) {
      return
    }

    this.dropdown.classList.remove("hidden")
    this.button?.setAttribute("aria-expanded", "true")
    this.setActive(this.selectedIndex())
  },

  close() {
    this.dropdown?.classList.add("hidden")
    this.button?.setAttribute("aria-expanded", "false")
    this.clearActive()
  },

  moveActive(step) {
    if (this.options.length === 0) {
      return
    }

    if (!this.isOpen()) {
      this.open()
      return
    }

    const nextIndex =
      this.activeIndex < 0
        ? 0
        : (this.activeIndex + step + this.options.length) % this.options.length

    this.setActive(nextIndex)
  },

  setActive(index) {
    if (this.options.length === 0) {
      return
    }

    const boundedIndex = Math.max(0, Math.min(index, this.options.length - 1))
    this.activeIndex = boundedIndex

    this.options.forEach((option, optionIndex) => {
      option.classList.toggle("is-active", optionIndex === boundedIndex)
    })

    this.options[boundedIndex]?.scrollIntoView({block: "nearest"})
  },

  clearActive() {
    this.activeIndex = -1
    this.options.forEach((option) => option.classList.remove("is-active"))
  },

  selectedIndex() {
    const selectedValue = this.input?.value ?? ""
    return this.options.findIndex((option) => option.dataset.value === selectedValue)
  },

  selectOption(option) {
    if (!option || !this.input) {
      return
    }

    const value = option.dataset.value ?? ""
    const label = option.dataset.label ?? option.textContent.trim()

    this.input.value = value
    this.valueLabel.textContent = label
    this.valueLabel.classList.toggle("aludel-select-placeholder", value === "")

    this.options.forEach((candidate) => {
      const isSelected = candidate === option
      candidate.classList.toggle("is-selected", isSelected)
      candidate.setAttribute("aria-selected", isSelected ? "true" : "false")

      const checkmark = candidate.querySelector(".aludel-select-check")
      checkmark?.classList.toggle("is-visible", isSelected)
    })

    this.input.dispatchEvent(new Event("input", {bubbles: true}))
    this.input.dispatchEvent(new Event("change", {bubbles: true}))

    this.close()
    this.button?.focus()
  },

  syncFromInput() {
    if (!this.input || !this.valueLabel) {
      return
    }

    const selectedValue = this.input.value ?? ""
    const selectedOption =
      this.options.find((option) => option.dataset.value === selectedValue) || this.options[0]

    if (selectedOption) {
      this.valueLabel.textContent = selectedOption.dataset.label ?? selectedOption.textContent.trim()
      this.valueLabel.classList.toggle("aludel-select-placeholder", selectedValue === "")
    }

    this.options.forEach((option) => {
      const isSelected = option.dataset.value === selectedValue
      option.classList.toggle("is-selected", isSelected)
      option.setAttribute("aria-selected", isSelected ? "true" : "false")

      const checkmark = option.querySelector(".aludel-select-check")
      checkmark?.classList.toggle("is-visible", isSelected)
    })

    this.activeIndex = this.selectedIndex()
  }
}
