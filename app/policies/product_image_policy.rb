# frozen_string_literal: true

class ProductImagePolicy < ApplicationPolicy
  def bulk_destroy?
    user_context.admin?
  end
end
