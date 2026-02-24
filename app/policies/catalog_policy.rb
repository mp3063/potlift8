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

  def sync_preview?
    true
  end

  def sync_status?
    true
  end

  def sync_alerts?
    true
  end

  def connect_shopify?
    user_context.admin?
  end

  def disconnect_shopify?
    user_context.admin?
  end

  def sync_all?
    user_context.can_write?
  end

  def sync_product?
    user_context.can_write?
  end

  def toggle_sync_pause?
    user_context.can_write?
  end
end
