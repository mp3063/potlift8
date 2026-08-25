# frozen_string_literal: true

# SECURITY: This controller should NEVER be enabled in production.
# The routes for this controller are only defined when Rails.env.test?
class TestSessionsController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :check_session_version
  skip_after_action :verify_authorized
  skip_forgery_protection

  def create
    unless Rails.env.test?
      head :not_found
      return
    end

    user = User.find(params[:user_id])
    company = user.company

    session[:user_id] = user.id
    session[:email] = user.email
    session[:user_name] = user.name
    session[:company_id] = params[:company_id].present? ? params[:company_id].to_i : company.id
    session[:company_code] = params[:company_code].presence || company.code
    session[:company_name] = params[:company_name].presence || company.name
    session[:role] = params[:role] || "admin"
    session[:scopes] = params[:scopes] || [ "read", "write" ]
    session[:access_token] = params[:access_token].presence || "test_token_#{SecureRandom.hex(16)}"
    session[:refresh_token] = params[:refresh_token].presence || "test_refresh_#{SecureRandom.hex(16)}"
    session[:expires_at] = params[:expires_at].present? ? params[:expires_at].to_i : 1.hour.from_now.to_i
    session[:authenticated_at] = params[:authenticated_at].present? ? params[:authenticated_at].to_i : Time.now.to_i
    session[:customer_groups] = []

    if request.get?
      redirect_to params[:redirect_to] || root_path
    else
      head :ok
    end
  end

  def destroy
    unless Rails.env.test?
      head :not_found
      return
    end

    reset_session
    head :ok
  end
end
