# frozen_string_literal: true

# SessionVersionChecker Service
#
# Checks session versions against Authlift8's Redis-stored versions
# to determine if cached session data needs to be refreshed.
#
# This service connects directly to the shared Redis instance used
# by Authlift8 to avoid unnecessary API calls for version checks.
#
# Usage:
#   checker = SessionVersionChecker.new(session)
#   if checker.needs_refresh?
#     checker.refresh_session!
#   end
#
class SessionVersionChecker
  REDIS_NAMESPACE = 'session_version'

  attr_reader :session

  def initialize(session)
    @session = session
  end

  # Check if session needs refresh (lightweight Redis check)
  # Returns true if any version is stale
  #
  # @return [Boolean] true if session data needs to be refreshed
  def needs_refresh?
    return false unless session[:user_id].present?

    user_stale? || company_stale? || customer_groups_stale?
  rescue Redis::BaseError => e
    Rails.logger.error("[SessionVersionChecker] Redis error: #{e.message}")
    false  # On Redis error, don't force refresh
  end

  # Refresh session data from Authlift8 API
  #
  # @return [Boolean] true if refresh succeeded
  def refresh_session!
    return false unless session[:access_token].present?

    Rails.logger.info(
      "[SessionVersionChecker] Refreshing session for user #{session[:user_id]}"
    )

    profile = fetch_profile_from_authlift8
    return false unless profile

    update_session_from_profile(profile)
    store_current_versions!

    Rails.logger.info(
      "[SessionVersionChecker] Session refreshed successfully for user #{session[:user_id]}"
    )

    true
  rescue StandardError => e
    Rails.logger.error(
      "[SessionVersionChecker] Refresh failed: #{e.message}"
    )
    false
  end

  # Store current versions in session (called after successful login or refresh)
  def store_current_versions!
    user_id = session[:user_id]
    company_id = session[:company_id]

    session[:session_version_user] = get_version(:user, user_id)
    session[:session_version_company] = company_id ? get_version(:company, company_id) : 0
    session[:session_version_customer_group] = company_id ? get_version(:customer_group, company_id) : 0
  end

  # Get current versions from Redis (for debugging)
  def current_versions
    {
      user: get_version(:user, session[:user_id]),
      company: session[:company_id] ? get_version(:company, session[:company_id]) : 0,
      customer_group: session[:company_id] ? get_version(:customer_group, session[:company_id]) : 0
    }
  end

  # Get stored versions from session (for debugging)
  def session_versions
    {
      user: session[:session_version_user].to_i,
      company: session[:session_version_company].to_i,
      customer_group: session[:session_version_customer_group].to_i
    }
  end

  private

  def user_stale?
    current = get_version(:user, session[:user_id])
    return false if current.zero?  # No version set = current
    session[:session_version_user].to_i < current
  end

  def company_stale?
    company_id = session[:company_id]
    return false unless company_id

    current = get_version(:company, company_id)
    return false if current.zero?
    session[:session_version_company].to_i < current
  end

  def customer_groups_stale?
    company_id = session[:company_id]
    return false unless company_id

    current = get_version(:customer_group, company_id)
    return false if current.zero?
    session[:session_version_customer_group].to_i < current
  end

  def get_version(entity_type, entity_id)
    return 0 unless entity_id

    key = "#{REDIS_NAMESPACE}:#{entity_type}:#{entity_id}"
    redis.get(key)&.to_i || 0
  end

  def fetch_profile_from_authlift8
    site = ENV.fetch('AUTHLIFT8_SITE', 'http://localhost:3231')

    response = Faraday.get("#{site}/api/v1/users/profile") do |req|
      req.headers['Authorization'] = "Bearer #{session[:access_token]}"
      req.headers['Content-Type'] = 'application/json'
      req.options.timeout = 5
      req.options.open_timeout = 3
    end

    return nil unless response.success?

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError => e
    Rails.logger.error(
      "[SessionVersionChecker] API error: #{e.message}"
    )
    nil
  end

  def update_session_from_profile(profile)
    # Update user data
    session[:email] = profile['email']
    session[:user_name] = profile['full_name']
    session[:locale] = profile['locale']

    # Update company data
    if profile['company']
      session[:company_id] = profile['company']['id']
      session[:company_code] = profile['company']['code']
      session[:company_name] = profile['company']['name']
      session[:customer_groups] = profile['company']['customer_groups'] || []
    end

    # Update membership data
    if profile['membership']
      session[:role] = profile['membership']['role']
      session[:scopes] = profile['membership']['scopes']
    end

    # Sync local User/Company records
    sync_local_records(profile)
  end

  def sync_local_records(profile)
    # Update User record
    if session[:user_id]
      user = User.find_by(id: session[:user_id])
      user&.update(
        email: profile['email'],
        name: profile['full_name']
      )
    end

    # Update Company record
    if profile['company']
      Company.from_authlift8(profile['company'])
    end
  end

  def redis
    @redis ||= Redis.new(
      url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
    )
  end
end
