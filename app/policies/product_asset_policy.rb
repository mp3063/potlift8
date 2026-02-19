# frozen_string_literal: true

class ProductAssetPolicy < ApplicationPolicy
  def bulk_destroy?
    user_context.admin?
  end
end
