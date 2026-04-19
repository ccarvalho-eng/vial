async function writeClipboard(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text)
    return
  }

  const textarea = document.createElement("textarea")
  textarea.value = text
  textarea.setAttribute("readonly", "")
  textarea.style.position = "absolute"
  textarea.style.left = "-9999px"
  document.body.appendChild(textarea)
  textarea.select()
  document.execCommand("copy")
  document.body.removeChild(textarea)
}

export const CopyToClipboard = {
  mounted() {
    this.defaultLabel = this.el.dataset.copyLabel || this.el.textContent.trim()
    this.handleClick = async event => {
      event.preventDefault()

      const targetId = this.el.dataset.copyTarget
      const target = targetId ? document.getElementById(targetId) : null

      if (!target) {
        this.showFeedback("Copy failed")
        return
      }

      try {
        await writeClipboard(target.textContent || "")
        this.showFeedback("Copied")
      } catch (_error) {
        this.showFeedback("Copy failed")
      }
    }

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    if (this.feedbackTimer) {
      clearTimeout(this.feedbackTimer)
    }

    this.el.removeEventListener("click", this.handleClick)
  },

  showFeedback(label) {
    this.el.textContent = label

    if (this.feedbackTimer) {
      clearTimeout(this.feedbackTimer)
    }

    this.feedbackTimer = setTimeout(() => {
      this.el.textContent = this.defaultLabel
    }, 1500)
  },
}
