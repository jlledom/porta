@javascript
@recaptcha
Feature: Login feature
  In order to protect the admin login screen from brute force attacks
  I want to detect bots with ReCaptcha V3

  Background:
    Given a provider "foo.3scale.localhost"

  Scenario: Captcha is disabled
    Given the master provider has bot protection disabled
    When they go to the provider login page
    Then the captcha is not present

  Scenario: Captcha is enabled
    Given the master provider has bot protection enabled
    When they go to the provider login page
    Then the captcha is present

  Scenario: Provider can log in with Captcha enabled
    Given the master provider has bot protection enabled
    And the client will not be marked as a bot
    When the provider logs in
    Then the current page is the provider dashboard

  Scenario: Captcha rejects a bot attempt also when it sends the correct credentials
    Given the master provider has bot protection enabled
    And the client will be marked as a bot
    When the provider logs in
    Then the current page is the provider failed login page
    And they should see "reCAPTCHA verification failed, please try again."
