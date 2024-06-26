require 'test_helper'

class Invoices::UnsuccessfullyChargedInvoiceFinalProviderEventTest < ActiveSupport::TestCase

  def test_create
    invoice = FactoryBot.build_stubbed(:invoice, id: 1, state: 'created')
    event   = Invoices::UnsuccessfullyChargedInvoiceFinalProviderEvent.create(invoice)

    assert event
    assert_equal event.invoice, invoice
    assert_equal event.provider, invoice.provider_account
    assert_equal event.state, invoice.state
  end
end
