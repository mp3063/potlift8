# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user_id

    def connect
      self.current_user_id = find_verified_user
    end

    private

    def find_verified_user
      user_id = request.session[:user_id]
      access_token = request.session[:access_token]

      if user_id.present? && access_token.present? && User.exists?(id: user_id)
        user_id
      else
        reject_unauthorized_connection
      end
    end
  end
end
