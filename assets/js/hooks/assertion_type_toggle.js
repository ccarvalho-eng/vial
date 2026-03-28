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
    if (e.target.matches('select[name^="assertion_type_"]')) {
      const idx = e.target.name.replace('assertion_type_', '')
      const type = e.target.value
      this.toggleFields(idx, type)
    }
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
    // Set initial state for all assertion type selects
    this.el.querySelectorAll('select[name^="assertion_type_"]').forEach(select => {
      const idx = select.name.replace('assertion_type_', '')
      const type = select.value
      this.toggleFields(idx, type)
    })
  }
}
