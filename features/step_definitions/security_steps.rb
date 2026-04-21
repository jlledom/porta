# frozen_string_literal: true

Given('the provider has configured {word} portal Permissions-Policy {string}') do |portal, policy_value|
  @provider.account_settings.create!(
    type: "AccountSetting::PermissionsPolicyHeader#{portal.capitalize}",
    value: policy_value
  )
end

Then('the {word} portal should have configured Permissions-Policy header {string}') do |portal, expected_value|
  setting = @provider.account_settings.find_by(type: "AccountSetting::PermissionsPolicyHeader#{portal.capitalize}")
  assert_not_nil setting, "Expected #{portal} portal Permissions-Policy setting to exist"
  assert_equal expected_value, setting.value
end

Then('the {word} portal should not have configured Permissions-Policy header') do |portal|
  setting = @provider.account_settings.find_by(type: "AccountSetting::PermissionsPolicyHeader#{portal.capitalize}")
  assert setting.nil? || setting.value.blank?, "Expected #{portal} portal Permissions-Policy to be blank or not exist"
end

Given('the provider has configured {word} portal CSP {string}') do |portal, csp_value|
  @provider.account_settings.create!(
    type: "AccountSetting::CspHeader#{portal.capitalize}",
    value: csp_value
  )
end

Then('the {word} portal should have configured CSP header {string}') do |portal, expected_value|
  setting = @provider.account_settings.find_by(type: "AccountSetting::CspHeader#{portal.capitalize}")
  assert_not_nil setting, "Expected #{portal} portal CSP setting to exist"
  assert_equal expected_value, setting.value
end

Then('the {word} portal should not have configured CSP header') do |portal|
  setting = @provider.account_settings.find_by(type: "AccountSetting::CspHeader#{portal.capitalize}")
  assert setting.nil? || setting.value.blank?, "Expected #{portal} portal CSP to be blank or not exist"
end

Then('the {word} portal should have CSP report-only enabled') do |portal|
  setting = @provider.account_settings.find_by(type: "AccountSetting::CspReportOnly#{portal.capitalize}")
  assert_not_nil setting, "Expected #{portal} portal CSP report-only setting to exist"
  assert_equal '1', setting.value
end
