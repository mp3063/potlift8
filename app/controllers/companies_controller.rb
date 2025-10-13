# frozen_string_literal: true

# Companies controller
#
# Handles company switching for users with access to multiple companies
#
class CompaniesController < ApplicationController
  # POST /switch_company/:id
  # Switch active company for current user
  #
  # This is a stub implementation. Full implementation will be added
  # when User model with company associations is created.
  def switch
    # TODO: Implement company switching when User model is ready
    # Expected implementation:
    # 1. Verify user has access to requested company
    # 2. Update session with new company context
    # 3. Redirect back with success message

    redirect_to root_path, alert: 'Company switching is not yet implemented'
  end
end
