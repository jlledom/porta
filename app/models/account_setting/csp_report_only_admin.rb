# frozen_string_literal: true

class AccountSetting::CspReportOnlyAdmin < AccountSetting::Boolean
  def self.display_name = "Content-Security-Policy Report-Only"
end
