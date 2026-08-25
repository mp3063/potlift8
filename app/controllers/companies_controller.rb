# frozen_string_literal: true

class CompaniesController < ApplicationController
  def switch
    authorize :company, :switch?

    # TODO: Implement company switching when User model is ready
    # Expected implementation:
    # 1. Verify user has access to requested company
    # 2. Update session with new company context
    # 3. Redirect back with success message

    redirect_to root_path, alert: "Company switching is not yet implemented"
  end
end
