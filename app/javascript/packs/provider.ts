import { renderVerticalNav } from 'Navigation/renderVerticalNav'
import { renderQuickStarts } from 'QuickStarts/renderQuickStarts'
import 'Common/threescale'
import application from 'Common/application'
import 'Common/ajaxEvents'
import { setUpToasts } from 'utilities/toast'

const jQuery1 = window.$

document.addEventListener('DOMContentLoaded', () => {
  renderVerticalNav()
  renderQuickStarts()

  application()
  setUpToasts()

  /**
   * This is a legacy functionality that could be replaced with standard PF forms.
   */
  document.querySelectorAll<HTMLFormElement>('form.autosubmit')
    .forEach(form => {
      form.addEventListener('change', () => {
        if (form.dataset.remote) {
          void window.Rails.handleRemote.call(form, jQuery1(form))
        } else {
          form.submit()
        }
      })
    })

  // Toggle target input(s) disabled state via [data-toggle-target] checkboxes.
  // If the target is an input, toggle it directly. If it's a container, toggle all inputs within.
  document.addEventListener('change', (event) => {
    const el = event.target as HTMLInputElement
    const targetId = el.getAttribute('data-toggle-target')
    if (targetId) {
      const target = document.getElementById(targetId)
      if (!target) return
      if (target instanceof HTMLInputElement) {
        target.disabled = !el.checked
      } else {
        target.querySelectorAll<HTMLInputElement>('input').forEach(input => {
          input.disabled = !el.checked
        })
      }
    }
  })
})
