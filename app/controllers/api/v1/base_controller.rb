# API Base Controller
#
# Base controller for all API v1 endpoints providing:
# - Bearer token authentication using Company.api_token
# - Automatic JSON response format
# - Multi-tenant scoping via @current_company
# - Standardized error handling
#
# Authentication:
# - Expects 'Authorization: Bearer <token>' header
# - Token must match a Company.api_token
# - Sets @current_company for multi-tenant scoping
#
# Error Handling:
# - 404 for RecordNotFound
# - 422 for RecordInvalid with validation errors
# - 401 for authentication failures
#
# @example Using in API controllers
#   class Api::V1::ProductsController < Api::V1::BaseController
#     def index
#       @products = @current_company.products.active_products
#       render json: @products
#     end
#   end
#
module Api
  module V1
    class BaseController < ActionController::API
      # Skip CSRF protection for API endpoints
      skip_before_action :verify_authenticity_token, raise: false

      # Require API authentication for all endpoints
      before_action :authenticate_api_request!

      # Error handling
      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      # Authenticate API request using Bearer token
      #
      # Extracts token from Authorization header and validates against Company.api_token.
      # Sets @current_company for use in controller actions.
      #
      # @raise [ActionController::RoutingError] if authentication fails
      #
      def authenticate_api_request!
        token = extract_token_from_header

        unless token.present?
          render_unauthorized('Missing authorization token')
          return
        end

        @current_company = Company.find_by(api_token: token, active: true)

        unless @current_company
          render_unauthorized('Invalid or inactive API token')
        end
      end

      # Extract Bearer token from Authorization header
      #
      # @return [String, nil] The API token or nil
      #
      def extract_token_from_header
        auth_header = request.headers['Authorization']
        return nil unless auth_header.present?

        # Expected format: "Bearer <token>"
        match = auth_header.match(/^Bearer\s+(.+)$/i)
        match[1] if match
      end

      # Render 401 Unauthorized error
      #
      # @param message [String] Error message
      #
      def render_unauthorized(message = 'Unauthorized')
        render json: {
          error: 'unauthorized',
          message: message
        }, status: :unauthorized
      end

      # Render 404 Not Found error
      #
      # @param exception [ActiveRecord::RecordNotFound] The exception
      #
      def render_not_found(exception)
        render json: {
          error: 'not_found',
          message: exception.message
        }, status: :not_found
      end

      # Render 422 Unprocessable Entity error with validation details
      #
      # @param exception [ActiveRecord::RecordInvalid] The exception
      #
      def render_unprocessable_entity(exception)
        render json: {
          error: 'validation_failed',
          message: exception.message,
          errors: exception.record.errors.as_json
        }, status: :unprocessable_entity
      end

      # Render 400 Bad Request error
      #
      # @param exception [ActionController::ParameterMissing] The exception
      #
      def render_bad_request(exception)
        render json: {
          error: 'bad_request',
          message: exception.message
        }, status: :bad_request
      end

      # Render success response with data
      #
      # @param data [Hash, Array] The data to return
      # @param status [Symbol] HTTP status (default: :ok)
      #
      def render_success(data, status: :ok)
        render json: data, status: status
      end

      # Render error response
      #
      # @param message [String] Error message
      # @param status [Symbol] HTTP status
      # @param error_code [String] Error code
      #
      def render_error(message, status: :internal_server_error, error_code: 'error')
        render json: {
          success: false,
          error: error_code,
          message: message
        }, status: status
      end
    end
  end
end
