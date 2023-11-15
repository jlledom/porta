# frozen_string_literal: true

When "I check hidden spam checkbox" do
  id = find("input[name*='confirmation'][type=checkbox]", visible: :hidden)[:id]
  page.evaluate_script <<-JS
    document.getElementById("#{id}").checked = true
  JS
end

When /^timestamp spam check will return probability (\d+)$/ do |value|
  stub_spam_protection_timestamp_probability(value.to_f)
end
