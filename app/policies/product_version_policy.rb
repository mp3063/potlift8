# frozen_string_literal: true

class ProductVersionPolicy < ApplicationPolicy
  def compare?
    true
  end

  def revert?
    user_context.admin?
  end
end
