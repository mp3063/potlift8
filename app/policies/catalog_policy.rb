# frozen_string_literal: true

class CatalogPolicy < ApplicationPolicy
  def items?
    true
  end

  def reorder_items?
    user_context.can_write?
  end

  def shopify_connection?
    true
  end

  def connect_shopify?
    user_context.admin?
  end

  def disconnect_shopify?
    user_context.admin?
  end
end
