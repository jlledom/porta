FactoryBot.define do
  factory(:profile) do
    association :account
  end

  factory(:forum) do
    name { 'Forum' }
    account {|a| a.association(:provider_account)}

    trait :public do
      after :create do |forum|
        forum.account.settings.update(forum_public: true)
      end
    end

    trait :private do
      after :create do |forum|
        forum.account.settings.update(forum_public: false)
      end
    end

    factory :public_forum, traits: [:public]
    factory :private_forum, traits: [:private]
  end

  factory(:topic_category) do
    name { 'Tech' }
  end

  factory(:topic) do
    title { "Title #{SecureRandom.hex}" }
    body { 'body body body of the first post' }
    association(:forum)
    association(:user, factory: :user_with_account)
  end

  factory(:post) do
    body { "Body of post" }
    user  { |post| post.association(:user_with_account) }
    topic { |post| post.association(:topic) }
  end

  factory(:service) do
    mandatory_app_key { false }
    sequence(:name) { |n| "service#{n}" }
    association(:account, :factory => :provider_account)
    after(:create) do |record|
      record.service_tokens.first_or_create!(value: 'token')
    end
  end

  factory(:service_token) do
    association :service
    sequence(:value) { |n| "value#{n}" }
  end

  factory(:metric) do
    association :owner, factory: :service
    sequence(:friendly_name) { |n| "Metric #{n}" }
    sequence(:unit) { |m| "metric_#{m}" }

    # TODO: use this factory throughout the codebase
    factory(:method) do
      parent { owner.metrics.hits }
    end
  end

  factory(:feature) do
    sequence(:name) { |n| "feature#{n}" }
  end

  factory(:usage_limit) do
    association(:plan, :factory => :application_plan)
    association(:metric)
    period { :month }
    value { 10_000 }
  end

  factory(:pricing_rule) do
    metric { |metric| metric.association(:metric) }
    cost_per_unit { 0.1 }
    sequence(:min) { |n| n }
    sequence(:max) { |n| n + 0.99 }
  end

  factory(:country) do
    sequence(:name) { |n| "country#{n}" }
    sequence(:code) { |n| "X#{n}" }
    currency { 'EUR' }
  end

  factory(:system_operation) do
    ref { "plan_change" }
    name { "Contract type change" }
    description { "" }
  end

  factory(:settings)

  factory(:webhook, :class => WebHook) do
    account { |wh| wh.association(:provider_account) }
    url { |wh| 'http://' + wh.account.external_domain }
    active { true }
    provider_actions { true }
  end

  factory(:payment_gateway_setting, :class => PaymentGatewaySetting) do
    gateway_type { :bogus }
    gateway_settings { { foo: :bar } }
    association :account
  end

  factory(:sso_authorization) do
    sequence(:uid) { |n| "#{n}234" }
    id_token { 'first-token' }
    association(:authentication_provider, factory: :authentication_provider)
    association(:user, factory: :user_with_account)
  end

  factory(:policy) do
    sequence(:name) { |n| "name #{n}" }
    sequence(:version) { |n| "1.0.#{n}" }
    schema do {
      '$schema' => "http://apicast.io/policy-v1/schema#manifest#",
      name: 'name example',
      version: version,
      configuration: {type: 'object'},
      summary: 'example summary',
      description: 'example description'
    }.as_json
    end
    association(:account, factory: :simple_provider)
  end

  factory(:oidc_configuration) do
    association(:oidc_configurable, factory: :proxy)
    standard_flow_enabled { true }
    implicit_flow_enabled { false }
    service_accounts_enabled { false }
    direct_access_grants_enabled { false }
  end
end
