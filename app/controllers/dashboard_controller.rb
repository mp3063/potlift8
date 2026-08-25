# frozen_string_literal: true

class DashboardController < ApplicationController
  skip_after_action :verify_authorized

  def index
    @company = current_potlift_company
  end
end
