# frozen_string_literal: true

module AccountSettings
  class SettingCache
    DEFAULT_EXPIRATION = 10.minutes

    class << self
      def fetch(account:, setting_name:, expires_in: DEFAULT_EXPIRATION)
        setting_name = setting_name.to_s
        klass = AccountSetting.class_for_setting(setting_name)
        return unless klass

        Rails.cache.fetch(cache_key(account, setting_name), expires_in: expires_in) do
          setting = klass.find_by(account:)
          setting ? setting.value : klass.default_value
        end
      end

      def set(account:, setting_name:, value:, expires_in: DEFAULT_EXPIRATION)
        setting_name = setting_name.to_s

        Rails.cache.write(cache_key(account, setting_name), value, expires_in: expires_in)
        value
      end

      private

      def cache_key(account, setting_name)
        "account_setting:#{account.id}:#{setting_name}"
      end
    end
  end
end
