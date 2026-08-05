PostHog.init do |config|
  config.api_key = "phc_w6bs8wB2bV7nLqcnM5iRsc5ixgwqVueTtDBgxnWPA6bw"
  config.host = "https://us.i.posthog.com"
  config.test_mode = true if Rails.env.test?
end

PostHog::Rails.configure do |config|
  config.auto_capture_exceptions = true
  config.report_rescued_exceptions = true
  config.auto_instrument_active_job = true
  config.capture_user_context = false
end
