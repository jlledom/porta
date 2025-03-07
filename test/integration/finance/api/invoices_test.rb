# frozen_string_literal: true

require 'test_helper'

module Finance::Api
  class InvoicesUnscopedTest < ActionDispatch::IntegrationTest
    def setup
      @provider = FactoryBot.create(:provider_account)
      @buyer = FactoryBot.create(:buyer_account, provider_account: @provider)
      @provider.create_billing_strategy
      @provider.save!
      @key = @provider.api_key

      host! @provider.external_admin_domain
      @context = ''
    end

    class WithoutExistingInvoices < InvoicesUnscopedTest
      test 'deny access without provider key' do
        get "/api/#{@context}invoices.xml"
        assert_response :forbidden
      end

      test 'deny access if finance module is disabled' do
        without_finance = FactoryBot.create(:provider_account, billing_strategy: nil)
        host! without_finance.internal_admin_domain
        get "/api/#{@context}invoices.xml?provider_key=#{without_finance.api_key}"
        assert_response :forbidden
        assert_match 'Finance module not enabled for the account', @response.body
      end

      test 'deny access if access token does not include finance scope' do
        @provider.settings.allow_finance!
        member = FactoryBot.create(:member, account: @provider, admin_sections: [:finance])
        token = FactoryBot.create(:access_token, owner: member)

        get "/api/invoices.xml?access_token=#{token.value}"

        assert_response :forbidden
      end

      test 'allow access if access token include finance scope' do
        @provider.settings.allow_finance!
        member = FactoryBot.create(:member, account: @provider, admin_sections: [:finance])
        token = FactoryBot.create(:access_token, owner: member, scopes: ['finance'])

        get "/api/invoices.xml?access_token=#{token.value}"

        assert_response :success
      end

      test 'deny access if member does not have finance permission' do
        @provider.settings.allow_finance!
        member = FactoryBot.create(:member, account: @provider, admin_sections: [])
        token = FactoryBot.create(:access_token, owner: member, scopes: ['finance'])

        get "/api/invoices.xml?access_token=#{token.value}"

        assert_response :forbidden
      end

      test 'return 404 on non-existent invoice' do
        get "/api/#{@context}invoices/42_ID.xml?provider_key=#{@key}"
        assert_response :not_found
      end
    end

    class WithExistingInvoices < InvoicesUnscopedTest
      def setup
        super
        @invoice = FactoryBot.create(:invoice, provider_account: @provider, buyer_account: @buyer)
        2.times { FactoryBot.create(:line_item_plan_cost, invoice: @invoice, name: 'fake', cost: 10.0) }
      end

      test 'return XML invoice specified by ID' do
        get "/api/#{@context}invoices/#{@invoice.id}.xml?provider_key=#{@key}"

        assert_response :success
        assert_select 'invoice' do
          assert_select 'invoice > id', text: @invoice.id.to_s
          assert_select 'invoice > friendly_id', text: @invoice.friendly_id.to_s
          assert_select 'invoice > buyer > id', @invoice.buyer_account.id.to_s
          assert_select 'line-items > line-item > cost', '10.0'
          assert_select 'invoice > cost', '20.0'
          # vat_rate and vat_amount do not show when vat_rate = 0
          assert_select 'invoice > vat_rate', text: "0", count: 0
          assert_select 'invoice > vat_amount', text: "0", count: 0
          assert_select 'invoice > cost_without_vat', '20.0'
          assert_select 'invoice > payment_transactions_count', "0"
        end
      end

      test 'work fine with deleted account' do
        buyer = FactoryBot.create(:buyer_account, provider_account: @provider)
        invoice = FactoryBot.create(:invoice, provider_account: @provider, buyer_account: buyer)
        buyer.delete # destroy

        get "/api/invoices/#{invoice.id}.xml?provider_key=#{@key}"

        assert_response :success
        assert_select 'invoice' do
          assert_select 'invoice > buyer > id', buyer.id.to_s
          assert_select 'invoice > buyer > status', "deleted"
        end
      end

      test "have vat_rate if non negative" do
        @buyer.vat_rate = 10.0
        @buyer.save

        get "/api/#{@context}invoices.xml?provider_key=#{@key}"

        assert_response :success
        assert_select 'invoice' do
          assert_select 'invoice > id', text: @invoice.id.to_s
          assert_select 'invoice > cost', '22.0'
          assert_select 'invoice > vat_rate', text: "10.0"
          assert_select 'invoice > vat_amount', '2.0'
          assert_select 'invoice > cost_without_vat', '20.0'
        end
      end

      test 'provide list of invoices' do
        25.times do
          FactoryBot.create(:invoice, provider_account: @provider, buyer_account: @buyer)
        end

        per_page = 21
        get "/api/#{@context}invoices.xml?provider_key=#{@key}&page=1&per_page=#{per_page}"

        assert_response :success
        assert_select 'invoices > pagination', total_pages: '2'
        assert_select 'invoices > pagination', current_page: '1'
        assert_select 'invoices > pagination', per_page: per_page.to_s
        assert_select 'invoices > invoice', count: per_page
      end

      test 'redirect when asked for PDF' do
        @invoice.generate_pdf!
        get "/api/#{@context}invoices/#{@invoice.id}.pdf?provider_key=#{@key}"
        assert_response :found

        redirect_url = response.header["Location"]

        assert_includes redirect_url, "/system/#{@provider.name}/invoices/#{@invoice.id}/pdfs/original/invoice-"

        uri = URI.parse(redirect_url)
        get "#{uri.path}?#{uri.query}"

        assert_response :ok
        assert_equal @invoice.pdf.size, response.body.size
      end

      test 'filter by month' do
        # Create an invoice 2 months after the first one
        new_invoice_period = @buyer.invoices.last.period.next.next
        FactoryBot.create(:invoice, provider_account: @provider, buyer_account: @buyer, period: new_invoice_period)

        get "/api/#{@context}invoices.xml?provider_key=#{@key}&month=#{new_invoice_period.to_param}"

        assert_response :success

        assert_select 'invoices > invoice', count: 1
      end

      test 'filter by state' do
        invoice = FactoryBot.create(:invoice, provider_account: @provider, buyer_account: @buyer)
        invoice.cancel!

        get "/api/#{@context}invoices.xml?provider_key=#{@key}&state=cancelled"

        assert_response :success

        assert_select 'invoices > invoice', count: 1
        assert_select 'invoices > invoice > id', text: invoice.id.to_s
        assert_select 'invoices > invoice > state', text: 'cancelled'
      end
    end
  end

  class InvoicesBuyersScopedTest < InvoicesUnscopedTest
    def setup
      super
      @context = "accounts/#{@buyer.id}/"
    end
  end
end
