# frozen_string_literal: true

class AccountSetting::CspHeaderAdmin < AccountSetting::HttpHeader
  def self.display_name = "Content-Security-Policy Header"

  self.default_value = ""

  if Rails.env.test?
    def self.reload_default_value!
      self.default_value = build_default_value
    end
  end
end
