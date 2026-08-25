# Authentication:
# - Expects 'Authorization: Bearer <token>' header
# - Token must match a Company.api_token
# - Sets @current_company for multi-tenant scoping
module Api
  module V1
    class BaseController < ActionController::API
      skip_before_action :verify_authenticity_token, raise: false

      before_action :authenticate_api_request!

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :render_bad_request

      private

      def user_for_paper_trail
        "API (#{@current_company&.name || 'Unknown'})"
      end

      def authenticate_api_request!
        token = extract_token_from_header

        unless token.present?
          render_unauthorized("Missing authorization token")
          return
        end

        @current_company = Company.authenticate_by_api_token(token)
        @current_company = nil if @current_company && !@current_company.active?

        unless @current_company
          render_unauthorized("Invalid or inactive API token")
        end
      end

      def extract_token_from_header
        auth_header = request.headers["Authorization"]
        return nil unless auth_header.present?

        match = auth_header.match(/^Bearer\s+(.+)$/i)
        match[1] if match
      end

      def render_unauthorized(message = "Unauthorized")
        render json: {
          error: "unauthorized",
          message: message
        }, status: :unauthorized
      end

      def render_not_found(exception)
        render json: {
          error: "not_found",
          message: exception.message
        }, status: :not_found
      end

      def render_unprocessable_entity(exception)
        render json: {
          error: "validation_failed",
          message: exception.message,
          errors: exception.record.errors.as_json
        }, status: :unprocessable_entity
      end

      def render_bad_request(exception)
        render json: {
          error: "bad_request",
          message: exception.message
        }, status: :bad_request
      end

      def render_success(data, status: :ok)
        render json: data, status: status
      end

      def render_error(message, status: :internal_server_error, error_code: "error")
        render json: {
          success: false,
          error: error_code,
          message: message
        }, status: status
      end
    end
  end
end
