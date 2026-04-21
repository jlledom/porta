# frozen_string_literal: true

require 'test_helper'

class CspHeadersTest < ActionDispatch::IntegrationTest

  test 'admin portal sets Content-Security-Policy header from AccountSetting' do
    provider = FactoryBot.create(:provider_account)
    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderAdmin',
      value: "default-src 'self'"
    )

    login_provider provider
    get edit_provider_admin_security_path

    assert_response :success
    assert_equal "default-src 'self'", response.headers['Content-Security-Policy']
  end

  test 'admin portal uses default Content-Security-Policy when no setting exists' do
    provider = FactoryBot.create(:provider_account)

    login_provider provider
    get edit_provider_admin_security_path

    assert_response :success
    assert_equal AccountSetting::CspHeaderAdmin.default_value,
                 response.headers['Content-Security-Policy']
  end

  test 'admin portal does not set header when setting is blank' do
    provider = FactoryBot.create(:provider_account)
    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderAdmin',
      value: ''
    )

    login_provider provider
    get edit_provider_admin_security_path

    assert_response :success
    assert_nil response.headers['Content-Security-Policy']
  end

  test 'developer portal sets Content-Security-Policy header from AccountSetting' do
    provider = FactoryBot.create(:provider_account)
    buyer = FactoryBot.create(:buyer_account, provider_account: provider)
    user = FactoryBot.create(:user, account: buyer)
    user.activate!

    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderDeveloper',
      value: "default-src 'self'"
    )

    DeveloperPortal::BaseController.any_instance.stubs(:site_account).returns(provider)

    host! provider.internal_domain
    login_with user.username, 'superSecret1234#'
    get '/admin'

    assert_response :success
    assert_equal "default-src 'self'", response.headers['Content-Security-Policy']
  end

  test 'developer portal does not set header when setting is blank (default)' do
    provider = FactoryBot.create(:provider_account)
    buyer = FactoryBot.create(:buyer_account, provider_account: provider)
    user = FactoryBot.create(:user, account: buyer)
    user.activate!

    DeveloperPortal::BaseController.any_instance.stubs(:site_account).returns(provider)

    host! provider.internal_domain
    login_with user.username, 'superSecret1234#'
    get '/admin'

    assert_response :success
    assert_nil response.headers['Content-Security-Policy']
  end

  test 'developer portal sets Content-Security-Policy header on unauthenticated pages' do
    provider = FactoryBot.create(:provider_account)
    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderDeveloper',
      value: "default-src 'self'"
    )

    host! provider.internal_domain
    get '/login'

    assert_response :success
    assert_equal "default-src 'self'", response.headers['Content-Security-Policy']
  end

  test 'admin portal uses Content-Security-Policy-Report-Only header when report-only is enabled' do
    provider = FactoryBot.create(:provider_account)
    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderAdmin',
      value: "default-src 'self'"
    )
    provider.account_settings.create!(
      type: 'AccountSetting::CspReportOnlyAdmin',
      value: '1'
    )

    login_provider provider
    get edit_provider_admin_security_path

    assert_response :success
    assert_equal "default-src 'self'", response.headers['Content-Security-Policy-Report-Only']
    assert_nil response.headers['Content-Security-Policy']
  end

  test 'admin portal uses Content-Security-Policy header when report-only is false' do
    provider = FactoryBot.create(:provider_account)
    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderAdmin',
      value: "default-src 'self'"
    )
    provider.account_settings.create!(
      type: 'AccountSetting::CspReportOnlyAdmin',
      value: '0'
    )

    login_provider provider
    get edit_provider_admin_security_path

    assert_response :success
    assert_equal "default-src 'self'", response.headers['Content-Security-Policy']
    assert_nil response.headers['Content-Security-Policy-Report-Only']
  end

  test 'developer portal uses Content-Security-Policy-Report-Only header when report-only is enabled' do
    provider = FactoryBot.create(:provider_account)
    buyer = FactoryBot.create(:buyer_account, provider_account: provider)
    user = FactoryBot.create(:user, account: buyer)
    user.activate!

    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderDeveloper',
      value: "default-src 'self'"
    )
    provider.account_settings.create!(
      type: 'AccountSetting::CspReportOnlyDeveloper',
      value: '1'
    )

    DeveloperPortal::BaseController.any_instance.stubs(:site_account).returns(provider)

    host! provider.internal_domain
    login_with user.username, 'superSecret1234#'
    get '/admin'

    assert_response :success
    assert_equal "default-src 'self'", response.headers['Content-Security-Policy-Report-Only']
    assert_nil response.headers['Content-Security-Policy']
  end

  test 'Sites controller (dev portal settings) uses admin Content-Security-Policy header' do
    provider = FactoryBot.create(:provider_account)
    login_provider provider

    provider.account_settings.create!(
      type: 'AccountSetting::CspHeaderDeveloper',
      value: "default-src 'none'"
    )

    get edit_admin_site_security_path

    assert_response :success
    # Admin portal pages get the admin CSP, not the developer one
    assert_equal AccountSetting::CspHeaderAdmin.default_value,
                 response.headers['Content-Security-Policy']
  end
end
