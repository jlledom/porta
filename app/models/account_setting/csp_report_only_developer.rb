# frozen_string_literal: true

class AccountSetting::CspReportOnlyDeveloper < AccountSetting::Boolean
  def self.display_name = "Content-Security-Policy Report-Only"
end
