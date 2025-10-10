# frozen_string_literal: true

require 'rails_helper'

# Example controller spec demonstrating authentication testing
# This shows how to use the AuthHelper for mocking authentication
#
# Run with: bundle exec rspec spec/controllers/application_controller_spec.rb

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :require_authentication, only: [:public_action]

    # Create a test action that requires authentication
    def index
      render json: { user_id: current_user[:id], authenticated: authenticated? }
    end

    # Create a test action that doesn't require authentication
    def public_action
      render json: { message: "public" }
    end
  end

  before do
    # Set up routes for the anonymous controller
    routes.draw do
      get 'index' => 'anonymous#index'
      get 'public_action' => 'anonymous#public_action'
    end
  end

  describe "Authentication" do
    context "when user is authenticated" do
      before do
        # Use the auth helper to sign in as a user
        sign_in_as(
          id: 123,
          email: "test@example.com",
          first_name: "Test",
          last_name: "User",
          company_id: 456,
          company_code: "ACME",
          company_name: "Acme Corp",
          role: "admin",
          scopes: ["read", "write"]
        )
      end

      it "allows access to protected actions" do
        get :index
        expect(response).to have_http_status(:success)
      end

      it "provides current_user data" do
        get :index
        json = JSON.parse(response.body)
        expect(json["user_id"]).to eq(123)
        expect(json["authenticated"]).to be true
      end
    end

    context "when user is not authenticated" do
      it "redirects to login page" do
        get :index
        expect(response).to redirect_to(auth_login_path)
      end

      it "sets flash alert message" do
        get :index
        expect(flash[:alert]).to eq('Please sign in to continue.')
      end
    end

    context "public actions" do
      it "allows access without authentication" do
        get :public_action
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe "#authenticated?" do
    it "returns false when no session exists" do
      expect(controller.send(:authenticated?)).to be false
    end

    it "returns true when valid session exists" do
      sign_in_as(id: 1, email: "user@example.com")
      # Set session data that authenticated? checks for
      session[:user_id] = 1
      session[:authenticated_at] = Time.now.to_i

      expect(controller.send(:authenticated?)).to be true
    end
  end

  describe "#current_user" do
    it "returns nil when not authenticated" do
      expect(controller.send(:current_user)).to be_nil
    end

    it "returns user data when authenticated" do
      session[:user_id] = 123
      session[:email] = "test@example.com"
      session[:user_name] = "Test User"
      session[:access_token] = "token"
      session[:authenticated_at] = Time.now.to_i

      user = controller.send(:current_user)
      expect(user[:id]).to eq(123)
      expect(user[:email]).to eq("test@example.com")
    end
  end
end
