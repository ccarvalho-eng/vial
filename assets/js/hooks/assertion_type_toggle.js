export const AssertionTypeToggle = {
  mounted() {
    this.handleToggle = this.handleToggle.bind(this)
    this.el.addEventListener('change', this.handleToggle)
    // Initialize on mount
    this.initializeFields()
  },

  updated() {
    // Re-initialize after LiveView updates
    this.initializeFields()
  },

  destroyed() {
    this.el.removeEventListener('change', this.handleToggle)
  },

  handleToggle(e) {
    // Get index from data-index attribute instead of parsing name
    const idx = this.el.getAttribute('data-index')
    const type = this.el.value
    this.toggleFields(idx, type)
  },

  toggleFields(idx, type) {
    const jsonFields = document.getElementById('json-fields-' + idx)
    const valueField = document.getElementById('value-field-' + idx)

    if (jsonFields && valueField) {
      if (type === 'json_field') {
        jsonFields.style.display = 'flex'
        valueField.style.display = 'none'
      } else {
        jsonFields.style.display = 'none'
        valueField.style.display = 'flex'
      }
    }
  },

  initializeFields() {
    // Initialize this select's fields on mount/update
    const idx = this.el.getAttribute('data-index')
    const type = this.el.value
    if (idx) {
      this.toggleFields(idx, type)
    }
  }
}
