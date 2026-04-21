# frozen_string_literal: true

module AccountSetting::CacheRefresh
  extend ActiveSupport::Concern

  included do
    after_commit :refresh_cache
  end

  private

  def refresh_cache
    cached_value = destroyed? ? default_value : value
    AccountSettings::SettingCache.set(account: account, setting_name: setting_name, value: cached_value)
  end
end
