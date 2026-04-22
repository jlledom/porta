# frozen_string_literal: true

class AccountSetting::CspReportOnlyHeaderAdmin < AccountSetting::HttpHeader
  def self.display_name = "Content-Security-Policy-Report-Only Header"

  self.default_value = ""
end
