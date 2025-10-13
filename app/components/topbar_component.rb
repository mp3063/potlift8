# frozen_string_literal: true

# Top navigation bar component
#
# Displays:
# - Mobile menu toggle button (hidden on desktop)
# - Global search bar with keyboard shortcut (⌘K)
# - Company selector dropdown (if user has multiple companies)
# - User profile menu dropdown
#
# Responsive:
# - Mobile: Hamburger menu button visible
# - Desktop: Full topbar with all elements visible
#
# @example Basic usage
#   <%= render TopbarComponent.new(
#     user: current_user,
#     company: current_potlift_company,
#     companies: current_user.accessible_companies
#   ) %>
#
class TopbarComponent < ViewComponent::Base
  # Initialize topbar component
  #
  # @param user [Hash] Current user hash with :id, :email, :name
  # @param company [Company] Current company
  # @param companies [Array<Company>] All accessible companies for user (optional)
  def initialize(user:, company:, companies: [])
    @user = user
    @company = company
    @companies = companies
  end

  private

  attr_reader :user, :company, :companies

  # Get user initials for avatar display
  #
  # @return [String] User initials (e.g., "JD" for "John Doe")
  def user_initials
    return "?" unless user && user[:name].present?

    user[:name].split.map(&:first).join.upcase.slice(0, 2)
  end

  # Check if user has multiple companies
  #
  # @return [Boolean] true if user has access to multiple companies
  def multiple_companies?
    companies.size > 1
  end
end
