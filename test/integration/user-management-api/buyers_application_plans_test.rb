# frozen_string_literal: true

require 'test_helper'

class Admin::Api::BuyersApplicationPlansTest < ActionDispatch::IntegrationTest
  include FieldsDefinitionsHelpers

  def setup
    @provider = FactoryBot.create(:provider_account, domain: 'provider.example.com')
    @service = @provider.services.first

    @buyer = FactoryBot.create(:buyer_account, :provider_account => @provider)
    @buyer.buy! @provider.default_account_plan

    @app_plan = FactoryBot.create(:application_plan, issuer: @provider.default_service)
    @buyer.buy! @app_plan
    @buyer.reload

    @provider.settings.allow_multiple_applications!
    @provider.settings.show_multiple_applications!
    @service.backend_version = "1"
    @service.save!


    host! @provider.external_admin_domain
  end

  test 'index (access_token)' do
    user = FactoryBot.create(:member, account: @provider)
    token = FactoryBot.create(:access_token, owner: user, scopes: 'account_management')

    get admin_api_account_application_plans_path(@buyer)
    assert_response :forbidden

    user.update(member_permission_ids: [:partners], member_permission_service_ids: [])

    get admin_api_account_application_plans_path(@buyer, access_token: token.value, format: :json)
    assert_response :success
    assert_equal 0, JSON.parse(response.body)['plans'].count

    user.update(member_permission_service_ids: [@provider.default_service.id])

    get admin_api_account_application_plans_path(@buyer, access_token: token.value, format: :json)
    assert_response :success
    assert_equal 1, JSON.parse(response.body)['plans'].count
  end

  test 'index' do
    get admin_api_account_application_plans_path(@buyer, format: :xml, provider_key: @provider.api_key)

    assert_response :success

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_not xml.xpath('.//plans').empty?
    assert_equal @app_plan.id.to_s, xml.xpath('.//plans/plan/id').children.first.to_s
    assert_equal @app_plan.name.to_s, xml.xpath('.//plans/plan/name').children.first.to_s
    assert_equal @app_plan.class.to_s.underscore, xml.xpath('.//plans/plan/type').children.first.to_s

    assert xml.xpath(".//plans/plan[@id='#{@buyer.bought_account_plan.id}']").empty?
  end

  test 'index for an inexistent account replies 404' do
    get admin_api_account_application_plans_path(0, format: :xml), params: { provider_key: @provider.api_key }

    assert_xml_404
  end

  test 'security wise: index is access denied in buyer side' do
    host! @provider.internal_domain
    get admin_api_account_application_plans_path(@buyer, format: :xml, provider_key: @provider.api_key)

    assert_response :forbidden
  end

  test 'buy' do
    app_plan = FactoryBot.create(:application_plan, issuer: @provider.default_service)

    post buy_admin_api_account_application_plan_path(@buyer, app_plan), params: { provider_key: @provider.api_key, format: :xml, name: "name", description: "description" }

    assert_response :success
    assert(@buyer.reload.bought_cinstances.detect {|c| c.plan_id == app_plan.id})

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_an_application_plan xml, @provider.default_service
    assert_equal app_plan.id.to_s, xml.xpath('/plan/id').children.text
  end

  test 'buy an already bought plan' do
    app_plan = FactoryBot.create(:application_plan, issuer: @provider.default_service)
    app_plan.publish!

    @buyer.buy! app_plan, { name: "name1", description: "description1" }

    post buy_admin_api_account_application_plan_path(@buyer, app_plan), params: { provider_key: @provider.api_key, format: :xml, name: "name2", description: "description2" }

    assert_response :success
    assert_equal 2, @buyer.reload.bought_cinstances.where(plan_id: app_plan.id).size

    #TODO: dry plan xml assertion into a helper
    #testing xml response
    xml = Nokogiri::XML::Document.parse(@response.body)

    assert_an_application_plan(xml, @provider.default_service)
    assert_equal app_plan.id.to_s, xml.xpath('/plan/id').children.text
  end

  test 'buy a custom plan is not allowed' do
    app_plan = FactoryBot.create(:application_plan, issuer: @provider.default_service)
    custom_plan = app_plan.customize

    post buy_admin_api_account_application_plan_path(@buyer, custom_plan), params: { provider_key: @provider.api_key, format: :xml, name: "name", description: "desc" }

    assert_xml_404
  end
end
