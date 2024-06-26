import type { JQueryXHR } from 'Types/jquery/v1'

const jQuery1 = window.$

export default function (): void {
  // disable links with 'data-disabled' attribute and display alert instead
  // delegation on body fires before rails.js. FIXME: this is not a valid guard. If "data-disabled"
  // removed manually from the DOM, the request will still go through. The link should be disabled
  // (not clickable) and the server should return a flash error.
  $('body').on('click', 'a[data-disabled]', (event) => {
    event.preventDefault()
    event.stopImmediatePropagation()
    alert((event.currentTarget as HTMLAnchorElement).dataset.disabled)
  })

  /**
   * This seems to be used only in app/views/master/providers/plans/_widget.html.slim:23
   * DEPRECATED: replace jquery/colorbox modals with Patternfly modals.
   * TODO: add a more specific selector to separate this form from all other "remote" ones.
   */
  $(document).on('submit', 'form.colorbox[data-remote]', (e) => {
    // MUST USE RAILS-JQUERY since ajax:complete is triggered by rails (do not use $ from node_modules).
    const $form = jQuery1(e.currentTarget as HTMLFormElement)
    const width = $form.data('width') as string | undefined
    $form.on('ajax:complete', (_event, xhr: JQueryXHR) => {
      jQuery1.colorbox({
        open: true,
        html: xhr.responseText,
        width,
        maxWidth: '85%',
        maxHeight: '90%'
      })
    })
  })

  // TODO: replace .fancybox with .colorbox
  // This link will load its content into a colorbox modal
  $(document).on('click', 'a.fancybox, a.colorbox', (e) => {
    jQuery1(e.currentTarget as HTMLAnchorElement).colorbox({ open: true })
    e.preventDefault()
  })

  // TODO: replace .fancybox with .colorbox
  // This is used in some modals with a "Cancel" button.
  $(document).on('click', '.fancybox-close', (e) => {
    jQuery1.colorbox.close()
    e.preventDefault()
    e.stopPropagation()
  })

  /**
   * Handle errors in formtastic forms rendered inside a colorbox. The error template is passed a
   * responseText inside the XHR response. MUST USE RAILS-JQUERY since ajax:error is triggered by
   * rails (do not use $ from node_modules).
   *
   * DEPRECATED: replace jquery/colorbox modals with Patternfly modals.
   * TODO: add a colorbox specific selector to separate this with non-legacy implementations.
   */
  jQuery1(document).on('ajax:error', 'form:not(.pf-c-form)', (event, xhr: JQueryXHR, status) => {
    if (status === 'error') {
      jQuery1.colorbox({ html: xhr.responseText })
      event.stopPropagation()
    }
  })
}
