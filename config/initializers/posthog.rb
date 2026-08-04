posthog_token = ENV["POSTHOG_PROJECT_TOKEN"]
posthog_host = ENV["POSTHOG_HOST"]

if posthog_token.present? && posthog_host.present?
  PostHog.init do |config|
    config.api_key = posthog_token
    config.host = posthog_host
  end

  PostHog::Rails.configure do |config|
    config.auto_capture_exceptions = true
    config.report_rescued_exceptions = true
    config.auto_instrument_active_job = true
    config.capture_user_context = false
  end
elsif Rails.env.development?
  missing_variable = posthog_token.present? ? "POSTHOG_HOST" : "POSTHOG_PROJECT_TOKEN"
  raise "#{missing_variable} variable required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once #{missing_variable} is configured"
end
