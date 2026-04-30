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
    const suffix = testCaseId ? testCaseId + '-' + idx : idx
    const jsonFields = document.getElementById('json-fields-' + suffix)
    const deepCompareFields = document.getElementById('deep-compare-fields-' + suffix)
    const valueField = document.getElementById('value-field-' + suffix)

    if (jsonFields && deepCompareFields && valueField) {
      if (type === 'json_field') {
        jsonFields.style.display = 'flex'
        deepCompareFields.style.display = 'none'
        valueField.style.display = 'none'
      } else if (type === 'json_deep_compare') {
        jsonFields.style.display = 'none'
        deepCompareFields.style.display = 'flex'
        valueField.style.display = 'none'
      } else {
        jsonFields.style.display = 'none'
        deepCompareFields.style.display = 'none'
        valueField.style.display = 'flex'
      }
    } else if (jsonFields && valueField) {
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
