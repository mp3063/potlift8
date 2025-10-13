# frozen_string_literal: true

# Dashboard controller
#
# Displays the main dashboard/home page after user authentication
#
class DashboardController < ApplicationController
  # GET /
  # Dashboard home page
  def index
    @company = current_potlift_company
  end
end
