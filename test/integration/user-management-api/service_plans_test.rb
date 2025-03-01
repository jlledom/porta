# frozen_string_literal: true

require 'test_helper'

class Admin::Api::ServicePlansTest < ActionDispatch::IntegrationTest
  def setup
    @provider = FactoryBot.create(:provider_account, domain: 'provider.example.com')

    plan = FactoryBot.create(:service_plan, issuer: @provider.default_service)
    plan.publish!
    FactoryBot.create(:service_plan, issuer: @provider.default_service)
    FactoryBot.create(:account_plan, issuer: @provider)
    FactoryBot.create(:application_plan, issuer: @provider.default_service)

    host! @provider.external_admin_domain
  end

  # Access token

  test 'show (access_token)' do
    user    = FactoryBot.create(:member, account: @provider, member_permission_ids: %i[partners plans], member_permission_service_ids: [])
    token   = FactoryBot.create(:access_token, owner: user, scopes: 'account_management')
    service = @provider.default_service
    plan    = service.service_plans.first

    get admin_api_service_service_plan_path(service, plan)
    assert_response :forbidden
    get admin_api_service_service_plan_path(service, plan), params: { access_token: token.value }
    assert_response :not_found
    user.update(member_permission_service_ids: [service.id])
    get admin_api_service_service_plan_path(service, plan), params: { access_token: token.value }
    assert_response :success
  end

  # Provider key

  test 'fast track: index' do
    get admin_api_service_plans_path(provider_key: @provider.api_key, format: :xml)

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_only_service_plans xml
  end

  test 'security wise: api is access denied in buyer side' do
    host! @provider.internal_domain
    get admin_api_service_plans_path(provider_key: @provider.api_key, format: :xml)

    assert_response :forbidden
  end

  test 'index' do
    service = FactoryBot.create(:service, account: @provider)
    FactoryBot.create(:service_plan, issuer: service)

    get admin_api_service_service_plans_path(service, provider_key: @provider.api_key, format: :xml)

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert(xml.xpath('.//plans/plan/service_id').all? { |t| t.text == service.id.to_s })

    assert_only_service_plans xml
  end

  test 'show' do
    get admin_api_service_service_plan_path(@provider.default_service, @provider.default_service.service_plans.first, provider_key: @provider.api_key, format: :xml)

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    #TODO: move this to service_plan_test#to_xml
    assert_a_service_plan xml, @provider.default_service
  end

  test 'create' do
    post admin_api_service_service_plans_path(@provider.default_service, format: :xml), params: { name: 'awesome service plan',
                                                                                                  state_event: 'publish',
                                                                                                  provider_key: @provider.api_key }

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_a_service_plan xml, @provider.default_service
    assert_equal xml.xpath('.//plan/name').children.first.to_s, 'awesome service plan'
    assert_equal xml.xpath('.//plan/state').children.first.to_s, 'published'
  end

  test 'update' do
    plan = FactoryBot.create(:service_plan, issuer: @provider.default_service, name: 'namy')

    put admin_api_service_service_plan_path(@provider.default_service, plan, format: :xml), params: { state_event: 'publish',
                                                                                                      name: 'new name',
                                                                                                      provider_key: @provider.api_key }

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_a_service_plan xml, @provider.default_service
    assert_equal xml.xpath('.//plan/name').children.first.to_s, 'new name'
    assert_equal xml.xpath('.//plan/state').children.first.to_s, 'published'
  end

  test 'default' do
    plan = FactoryBot.create(:service_plan, issuer: @provider.default_service, name: 'namy')
    plan.publish!

    put default_admin_api_service_service_plan_path(@provider.default_service, plan, format: :xml), params: { provider_key: @provider.api_key }

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_a_service_plan xml, @provider.default_service
    assert_not xml.xpath('.//plan[@default="true"]').empty?
  end

  pending_test 'hidden plan cannot be mark as default' do
    plan = FactoryBot.create(:service_plan, issuer: @provider.default_service, name: 'namy', state: :hidden)
    put default_admin_api_service_service_plan_path(@provider.default_service, plan, format: :xml), params: { provider_key: @provider.api_key }
    assert_response :unprocessable_entity
  end

  test 'destroy' do
    service_plan = FactoryBot.create(:service_plan, issuer: @provider.default_service)

    delete admin_api_service_service_plan_path(@provider.default_service, service_plan), params: { provider_key: @provider.api_key, format: :xml, method: '_destroy' }

    assert_response :success
    assert_not @response.body.presence

    assert_raise ActiveRecord::RecordNotFound do
      service_plan.reload
    end
  end

  test 'destroy returns error when deletion failed' do
    #TODO: move this to some setup
    service_plan = FactoryBot.create(:service_plan, issuer: @provider.first_service!)
    buyer = FactoryBot.create(:buyer_account, provider_account: @provider)
    buyer.buy! service_plan

    delete admin_api_service_service_plan_path(@provider.first_service!, service_plan), params: { provider_key: @provider.api_key, format: :xml, method: '_destroy' }

    assert_response :forbidden
    assert_xml_error(@response.body, "This service plan cannot be deleted")
  end
end
