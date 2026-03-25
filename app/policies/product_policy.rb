# frozen_string_literal: true

class ProductPolicy < ApplicationPolicy
  def duplicate?
    user_context.can_write?
  end

  def validate_sku?
    true
  end

  def toggle_active?
    user_context.can_write?
  end

  def activate_variants?
    user_context.can_write?
  end

  def attribute_value?
    true
  end
end
