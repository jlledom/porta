# frozen_string_literal: true

class AccountSetting::Boolean < AccountSetting
  include AccountSetting::CacheRefresh

  self.default_value = "0"

  validates :value, inclusion: { in: %w[0 1] }
end
