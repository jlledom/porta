# frozen_string_literal: true

require 'test_helper'

class Admin::Api::ApplicationPlanLimitsTest < ActionDispatch::IntegrationTest
  def setup
    @provider = FactoryBot.create(:provider_account, domain: 'provider.example.com')
    @service = FactoryBot.create(:service, account: @provider)
    @app_plan = FactoryBot.create(:application_plan, issuer: @service)
    @metric = FactoryBot.create(:metric, owner: @service)
    @limit = FactoryBot.create(:usage_limit, plan: @app_plan, metric: @metric)

    host! @provider.external_admin_domain
  end

  class AccessTokenTest < Admin::Api::ApplicationPlanLimitsTest
    def setup
      super
      @user = FactoryBot.create(:member, account: @provider, member_permission_ids: %i[partners plans], member_permission_service_ids: [])
      @token = FactoryBot.create(:access_token, owner: @user, scopes: 'account_management')

      User.any_instance.stubs(:has_access_to_all_services?).returns(false)
    end

    test 'index with no token' do
      get admin_api_application_plan_limits_path(@app_plan)
      assert_response :forbidden
    end

    test 'index with access to no services' do
      get admin_api_application_plan_limits_path(@app_plan), params: params
      assert_response :not_found
    end

    test 'index with access to some service' do
      @user.update(member_permission_service_ids: [@service.id])
      get admin_api_application_plan_limits_path(@app_plan), params: params
      assert_response :success
    end

    test 'index with access to all services' do
      @user.update(member_permission_service_ids: nil)
      get admin_api_application_plan_limits_path(@app_plan), params: params
      assert_response :success
    end

    private

    def access_token_params(token = @token)
      { access_token: token.value }
    end

    alias params access_token_params
  end

  class ProviderKeyTest < Admin::Api::ApplicationPlanLimitsTest
    test 'application_plan not found' do
      get admin_api_application_plan_limits_path(application_plan_id: 0, format: :xml), params: params
      assert_response :not_found
    end

    test 'application_plan_limits_index' do
      get admin_api_application_plan_limits_path(@app_plan, format: :xml), params: params
      assert_response :success

      assert_usage_limits(@response.body, { plan_id: @app_plan.id, metric_id: @metric.id })
    end

    private

    def provider_key_params
      { provider_key: @provider.api_key }
    end

    alias params provider_key_params
  end
end
