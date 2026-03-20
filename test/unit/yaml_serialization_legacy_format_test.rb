# frozen_string_literal: true

require 'test_helper'

class YamlSerializationLegacyFormatTest < ActiveSupport::TestCase
  # Some model attributes that are represented as Hash (or, more specifically, HashWithIndifferentAccess)
  # were serialized as YAML in the database, with the prefix !map:HashWithIndifferentAccess (used in older versions of Rails)
  # Trying to deserialize such values was causing an exception:
  #    Psych::DisallowedClass: Tried to load unspecified class: HashWithIndifferentAccess
  #
  # The fix is in config/application.rb where 'HashWithIndifferentAccess' (as a string)
  # is added to yaml_column_permitted_classes.
  #
  # An example of such field is 'extra_fields' in Account, Cinstance, User models, but there might be others
  test 'can deserialize legacy HashWithIndifferentAccess YAML format in Cinstance extra_fields' do
    # Setup: Create a provider account that will own the fields definitions
    provider = FactoryBot.create(:provider_account)

    # Setup: Create custom field definition for Cinstance (applications)
    FactoryBot.create(:fields_definition, account: provider,
      target: 'Cinstance', name: 'custom_field', label: 'Custom Field'
    )

    # Setup: Create a buyer account and an application (Cinstance)
    plan = FactoryBot.create(:application_plan, issuer: provider.first_service!)
    application = FactoryBot.create(:cinstance, plan: plan)

    # Simulate legacy data: Update the extra_fields column directly with old YAML format
    # This is what exists in production databases from older Rails versions
    legacy_yaml = <<~YAML.strip
      --- !map:HashWithIndifferentAccess
      custom_field: custom_value
    YAML

    ActiveRecord::Base.connection.execute(
      "UPDATE cinstances SET extra_fields = #{ActiveRecord::Base.connection.quote(legacy_yaml)} WHERE id = #{application.id}"
    )

    # Test: Reload the application and verify the legacy YAML can be deserialized
    application.reload

    assert_instance_of ActiveSupport::HashWithIndifferentAccess, application.extra_fields

    # Verify the field values are correctly deserialized
    assert_equal 'custom_value', application.extra_fields['custom_field']
    assert_equal 'custom_value', application.extra_fields[:custom_field]

    # Re-save to trigger modern serialization
    application.save!

    # Check the raw database value - should not contain old tag
    raw_yaml = ActiveRecord::Base.connection.select_value(
      "SELECT extra_fields FROM cinstances WHERE id = #{application.id}"
    )

    assert_not_includes raw_yaml, '!map:HashWithIndifferentAccess',
                        'Re-serialized extra_fields should use modern format'
    assert_includes raw_yaml, '!ruby/hash:ActiveSupport::HashWithIndifferentAccess',
                    'Re-serialized extra_fields should use modern format'

    # But data should still be accessible
    application.reload
    assert_equal 'custom_value', application.extra_fields['custom_field']
    assert_equal 'custom_value', application.extra_fields[:custom_field]
  end
end
