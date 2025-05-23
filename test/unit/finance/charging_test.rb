# frozen_string_literal: true

require 'test_helper'

class Finance::ChargingTest < ActiveSupport::TestCase
  setup do
    Invoice.any_instance.stubs log_entry_created: true
    @provider_account = FactoryBot.create(:provider_account, billing_strategy: FactoryBot.create(:postpaid_billing))

    @provider_account.bought_plan.enable_feature!(:postpaid_billing)
    @plan = FactoryBot.create(:application_plan, issuer: @provider_account.default_service)

    @buyer_account = FactoryBot.create(:buyer_account, provider_account: @provider_account)
    @cinstance = @buyer_account.buy!(@plan)
  end

  class BuyerNotPayingMonthlyTest < Finance::ChargingTest
    setup do
      @buyer_account.not_paying_monthly!
      @invoice = @provider_account.billing_strategy.create_invoice!(buyer_account: @buyer_account)
      @invoice.line_items << LineItem.new(cost: 100)
      @invoice.save!
      @invoice.issue_and_pay_if_free!
    end

    test 'should leave the invoice as unpaid' do
      @invoice.charge!
      assert_not @invoice.paid?
    end

    test 'should return false' do
      assert_not @invoice.charge!
    end

    test 'should not send charge notification email' do
      InvoiceMessenger.expects(:successfully_charged).never
      @invoice.charge!
    end

    test 'should not send analytics notification' do
      # FIXME: this is evergreen
      UserTrackingHelper.expects(:analytics_track).never
      @invoice.charge!
    end
  end

  class BuyerChargedMonthlyTest < Finance::ChargingTest
    setup do
      @buyer_account.paying_monthly!

      @invoice = Invoice.new(provider_account: @provider_account, buyer_account: @buyer_account,
                                                                  friendly_id: '0000-00-00000001',
                                                                  period: Month.new(Time.zone.now))
      @invoice.line_items << LineItem.new(cost: 100)
      @invoice.save!
      @invoice.issue_and_pay_if_free!
    end

    class NotChargedTest < BuyerChargedMonthlyTest
      test 'should not charge if invoice already paid' do
        @invoice.paid_at = 1.week.ago
        @invoice.save!

        @provider_account.payment_gateway.class.any_instance.expects(:purchase).never
        @invoice.charge!
      end

      test 'should not charge if provider does not exists' do
        @invoice.expects(:provider).returns(nil).at_least_once
        @buyer_account.expects(:charge!).never
        @invoice.charge!
      end

      test 'should not charge if credit card is invalid' do
        @buyer_account.credit_card_auth_code = nil

        @buyer_account.save!

        @provider_account.payment_gateway.class.any_instance.expects(:purchase).never
        @invoice.charge!

        assert_not @invoice.paid?
      end
    end

    class Foo < BuyerChargedMonthlyTest
      test 'should charge if credit card is expired' do
        @buyer_account.credit_card_expires_on_year = 2.years.ago.year
        @buyer_account.credit_card_expires_on_month = 2.years.ago.month
        @buyer_account.credit_card_auth_code = 'SECRET'

        @buyer_account.save!


        travel_to(3.years.from_now) do
          @provider_account.payment_gateway.class.any_instance.expects(:purchase)
          .with(10000, @buyer_account.credit_card_auth_code, has_key(:order_id))
          .returns(stub('response', :success? => false, :authorization => '1234',
                        :message => 'whatever', :params => {'foo' => 'bar'}, :test => false))

          @invoice.charge!
        end

        assert_not @invoice.paid?
      end
    end

    class PaymentGatewayRespondsFailureTest < BuyerChargedMonthlyTest
      setup do
        @buyer_account.credit_card_expires_on_year = 2.years.from_now.year
        @buyer_account.credit_card_expires_on_month = 2.years.from_now.month
        @buyer_account.credit_card_auth_code = 'pg responds failure if code ends in 2'

        @buyer_account.save!

        @provider_account.payment_gateway.class.any_instance.expects(:purchase)
          .with(10000, @buyer_account.credit_card_auth_code, has_key(:order_id))
          .returns(stub('response', :success? => false, :authorization => '1234',
                        :message => 'whatever', :params => {'foo' => 'bar'}, :test => false))
      end

      test 'should not mark invoice as paid' do
        @invoice.charge!
        assert_not @invoice.paid?
      end

      test 'should record payment transaction' do
        assert_difference 'PaymentTransaction.count', 1 do
          @invoice.charge!
        end

        transaction = PaymentTransaction.last
        assert_equal @invoice, transaction.invoice
        assert_not transaction.success?
      end

      test 'should log_entry error' do
        @invoice.charge!
        assert_equal 1, LogEntry.count
        assert_equal :error, LogEntry.first.level
      end

      test 'should notify buyer and provider accounts about failed first attempt to charge' do
        message = stub(:deliver => nil)

        InvoiceMessenger.expects(:unsuccessfully_charged_for_buyer)
          .with(@invoice).returns(message)
        Invoices::UnsuccessfullyChargedInvoiceProviderEvent.expects(:create).with(@invoice)

        @invoice.charge!
      end
    end

    class PaymentGatewayRisesExceptionTest < BuyerChargedMonthlyTest
      setup do
        @buyer_account.credit_card_expires_on_year = 2.years.from_now.year
        @buyer_account.credit_card_expires_on_month = 2.years.from_now.month
        @buyer_account.credit_card_auth_code = 'pg responds failure if code ends in 3'

        @buyer_account.save!

        @provider_account.payment_gateway.class.any_instance.expects(:purchase)
          .raises(ActiveMerchant::ActiveMerchantError, 'boo')
      end

      test 'should not mark invoice as paid' do
        @invoice.charge!
        assert_not @invoice.paid?
      end

      test 'should log_entry error' do
        @invoice.charge!
        assert_equal 1, LogEntry.count
        assert_equal :error, LogEntry.first.level
      end

      test 'should record payment transaction' do
        assert_difference 'PaymentTransaction.count', 1 do
          @invoice.charge!
        end

        transaction = PaymentTransaction.last
        assert_equal @invoice, transaction.invoice
        assert_not transaction.success?
      end
    end

    class PaymentGatewayRespondsSuccessTest < BuyerChargedMonthlyTest
      setup do
        @buyer_account.credit_card_expires_on_year = 2.years.from_now.year
        @buyer_account.credit_card_expires_on_month = 2.years.from_now.month
        @buyer_account.credit_card_auth_code = 'pg responds failure if code ends in 1'

        @buyer_account.save!

        @provider_account.payment_gateway.class.any_instance.expects(:purchase)
          .with(10000, @buyer_account.credit_card_auth_code, has_key(:order_id))
          .returns(stub('response', :success? => true, :authorization => '1234',
                        :message => 'whatever', :params => {'foo' => 'bar'}, :test => false))
      end

      test 'should mark the invoice as paid' do
        @invoice.mark_as_unpaid!
        @invoice.charge!
        assert @invoice.paid?
      end

      test 'should not send analytics notification' do
        # FIXME: this is evergreen
        UserTrackingHelper.expects(:analytics_track).never
        @invoice.charge!
      end

      test 'should record payment transaction' do
        assert_difference 'PaymentTransaction.count', 1 do
          @invoice.charge!
        end

        transaction = PaymentTransaction.last
        assert_equal @invoice, transaction.invoice
        assert transaction.success?
      end

      test 'should log_entry info' do
        @invoice.charge!
        assert_equal 1, LogEntry.count
        assert_equal :info, LogEntry.first.level
      end
    end
  end
end

class Finance::BuyerNotificationWhenPaidTest < ActiveSupport::TestCase
  setup do
    @provider_account = FactoryBot.create(:provider_account, billing_strategy: FactoryBot.create(:postpaid_billing))

    @provider_account.bought_plan.enable_feature!(:postpaid_billing)
    @plan = FactoryBot.create(:application_plan, issuer: @provider_account.default_service)

    @buyer_account = FactoryBot.create(:buyer_account, provider_account: @provider_account)
    @cinstance = @buyer_account.buy!(@plan)

    @buyer_account.paying_monthly!

    @invoice = Invoice.new(provider_account: @provider_account, buyer_account: @buyer_account,
                                                                friendly_id: '0000-00-00000001',
                                                                period: Month.new(Time.zone.now))
    @invoice.line_items << LineItem.new(cost: 100)
    @invoice.save!
    @invoice.issue_and_pay_if_free!
  end

  test 'send buyer notification on successful payment' do
    message = stub(:deliver => nil)
    Logic::RollingUpdates.stubs(skipped?: true)
    Account.any_instance.expects(:charge!).returns(true)

    InvoiceMessenger.expects(:successfully_charged)
      .with(@invoice).returns(message)
    assert @invoice.charge!
  end
end
