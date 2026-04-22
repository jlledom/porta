# frozen_string_literal: true

class AccountSetting::CspReportOnlyHeaderAdmin < AccountSetting::HttpHeaders
  def self.display_name = "Content-Security-Policy-Report-Only Header"

  self.default_value = ""
end
