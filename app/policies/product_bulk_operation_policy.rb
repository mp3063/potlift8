# frozen_string_literal: true

class ProductBulkOperationPolicy < ApplicationPolicy
  def update_labels?
    user_context.can_write?
  end

  def labels_for_products?
    true
  end
end
