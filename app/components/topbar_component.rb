# frozen_string_literal: true

class TopbarComponent < ViewComponent::Base
  def initialize(user:, company:, companies: [])
    @user = user
    @company = company
    @companies = companies
  end

  private

  attr_reader :user, :company, :companies

  def user_initials
    return "?" unless user && user[:name].present?

    user[:name].split.map(&:first).join.upcase.slice(0, 2)
  end

  def multiple_companies?
    companies.size > 1
  end
end
