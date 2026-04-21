# frozen_string_literal: true

module DeveloperPortal
  class ApplicationController < ::FrontendController

    before_action :disable_for_suspended_provider_account

    protected

    def disable_for_suspended_provider_account
      if site_account && site_account.suspended?
        handle_buyer_side(:not_found)
      end
    end

    private

    def set_permissions_policy_header
      header_value = AccountSettings::SettingCache.fetch(
        account: site_account,
        setting_name: 'permissions_policy_header_developer'
      )

      # Set header only if value is present (even if only whitespaces)
      response.headers['Permissions-Policy'] = header_value if header_value&.size&.nonzero?
    end

    def set_csp_header
      header_value = AccountSettings::SettingCache.fetch(
        account: site_account,
        setting_name: 'csp_header_developer'
      )
      return unless header_value&.size&.nonzero?

      report_only = AccountSettings::SettingCache.fetch(
        account: site_account,
        setting_name: 'csp_report_only_developer'
      )

      header_name = report_only == "1" ? 'Content-Security-Policy-Report-Only' : 'Content-Security-Policy'
      response.headers[header_name] = header_value
    end
  end
end
