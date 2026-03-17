# frozen_string_literal: true

class ProductInventoryPolicy < ApplicationPolicy
  def batch_update?
    update?
  end
end
