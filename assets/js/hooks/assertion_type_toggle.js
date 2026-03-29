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
    const idx = this.el.getAttribute('data-index')
    const testCaseId = this.el.getAttribute('data-test-case-id')
    const type = this.el.value
    this.toggleFields(idx, testCaseId, type)
  },

  toggleFields(idx, testCaseId, type) {
    // Include test case ID if available to prevent collisions
    const suffix = testCaseId ? testCaseId + '-' + idx : idx
    const jsonFields = document.getElementById('json-fields-' + suffix)
    const valueField = document.getElementById('value-field-' + suffix)

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
    const idx = this.el.getAttribute('data-index')
    const testCaseId = this.el.getAttribute('data-test-case-id')
    const type = this.el.value
    if (idx) {
      this.toggleFields(idx, testCaseId, type)
    }
  }
}
