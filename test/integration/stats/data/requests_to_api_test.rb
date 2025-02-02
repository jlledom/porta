# frozen_string_literal: true

require 'test_helper'

class Stats::Data::RequestsToApiTest < ActionDispatch::IntegrationTest

  def setup
    @provider_account = FactoryBot.create(:provider_account)
    @service          = @provider_account.default_service
    @plan             = FactoryBot.create(:simple_application_plan, issuer: @service)
    @buyer_account    = FactoryBot.create(:simple_buyer, provider_account: @provider_account)
    @application      = @buyer_account.buy!(@plan)

    host! @provider_account.internal_admin_domain
  end

  # Applications Usage

  # Access token

  test 'usage with access token' do
    member = FactoryBot.create(:member, account: @provider_account, admin_sections: ['monitoring'])
    token  = FactoryBot.create(:access_token, owner: member, scopes: ['stats'])
    params = { period: 'day', metric_name: 'hits', access_token: token.value }

    # token includes the right scope, member has the right permission, all services are accessible
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :success

    token.scopes = ['finance']
    token.save!
    # token does not include the right scope
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :forbidden

    token.scopes = ['stats']
    token.save!

    # member does not have the right permission
    member.update(member_permission_ids: [])
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :forbidden

    # the service is not accessible for the member
    member.update(member_permission_ids: [:monitoring], member_permission_service_ids: [])
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :forbidden

    # the service is accessible for the member
    member.update(member_permission_service_ids: [@service.id])
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :success
  end

  test 'summary with access token' do
    member = FactoryBot.create(:member, account: @provider_account, admin_sections: ['monitoring'])
    token  = FactoryBot.create(:access_token, owner: member, scopes: ['stats'])
    params = { period: 'day', metric_name: 'hits', access_token: token.value }

    get summary_stats_data_applications_path(@application, format: :json), params: params
    assert_response :success
  end

  # Provider key

  test 'respond on json for applications' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :success
    assert_media_type 'application/json'
  end

  test 'respond on xml for applications' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_applications_path(@application, format: :xml), params: params
    assert_response :success
    assert_media_type 'application/xml'
  end

  test 'not returning change if asked' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key, skip_change: 'false' }
    get usage_stats_data_applications_path(@application, format: :xml), params: params
    assert_response :success
    assert_media_type 'application/xml'
    assert_no_match 'change', @response.body
  end

  test 'not returning change by default' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :success
    assert_not data['change']
    assert_media_type 'application/json'
  end

  test 'returning change if asked' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key, skip_change: 'false' }
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :success
    assert data['change'], "#{data} should have change key"
    assert_media_type 'application/json'
  end

  test 'respond when missing params for applications' do
    params = { period: 'day', provider_key: @provider_account.api_key }
    get usage_stats_data_applications_path(@application, format: :xml), params: params
    assert_response :bad_request
    assert_media_type 'text/plain'
  end

  test 'response when application not found' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_applications_path(application_id: 'XXX', format: :json), params: params
    assert_response :not_found
    assert_media_type 'application/json'
    assert_equal '{"error":"Application not found"}', @response.body
  end

  test 'respond when provided with non-existent metric for applications' do
    params = { period: 'day', metric_name: "xxxx", provider_key: @provider_account.api_key }
    get usage_stats_data_applications_path(@application, format: :json), params: params
    assert_response :bad_request
    assert_media_type 'application/json'
    assert_equal '{"error":"metric xxxx not found"}', @response.body
  end


  # Services

  test 'respond on json for services' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_services_path(@service, format: :json), params: params
    assert_response :success
    assert_media_type 'application/json'
  end

  test 'respond on json for services in negative timezone and very old times' do
    params = { period: 'month', since: '0150-12-01', timezone: 'Pacific Time (US & Canada)', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_services_path(@service, format: :json), params: params
    assert_response :success
    assert_media_type 'application/json'

    # to trigger the shift > 0 conditions
    get usage_stats_data_services_path(@service, format: :json), params: params.merge(timezone: 'New Delhi')
    assert_response :success
    assert_media_type 'application/json'

    # to trigger the granularity == :month condition
    get usage_stats_data_services_path(@service, format: :json), params: params.merge(period: 'year')
    assert_response :success
    assert_media_type 'application/json'

    # to trigger both the shift > 0 conditions and granularity == :month
    get usage_stats_data_services_path(@service, format: :json), params: params.merge(period: 'year', timezone: 'New Delhi')
    assert_response :success
    assert_media_type 'application/json'
  end

  test 'respond on xml for services' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_services_path(@service, format: :xml), params: params
    assert_response :success
    assert_media_type 'application/xml'
  end

  test 'respond when missing params for services' do
    params = { period: 'day', provider_key: @provider_account.api_key }
    get usage_stats_data_services_path(@service, format: :xml), params: params
    assert_response :bad_request
    assert_media_type 'text/plain'
  end

  test 'respond when provided with non-existent metric for services' do
    params = { period: 'day', metric_name: "xxxx", provider_key: @provider_account.api_key }
    get usage_stats_data_services_path(@service, format: :json), params: params
    assert_response :bad_request
    assert_media_type 'application/json'
    assert_equal '{"error":"metric xxxx not found"}', @response.body
  end

  test 'response when service not found' do
    params = { period: 'day', metric_name: "hits", provider_key: @provider_account.api_key }
    get usage_stats_data_services_path(service_id: 'XXX', format: :json), params: params
    assert_response :not_found
    assert_media_type 'application/json'
    assert_equal '{"error":"Service not found"}', @response.body
  end

  private

  def data
    case @response.content_type
    when /xml/ then Hash.from_xml(@response.body)
    when /json/ then JSON.parse(@response.body)
    end
  end
end
