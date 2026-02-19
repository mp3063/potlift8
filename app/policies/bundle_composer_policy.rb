# frozen_string_literal: true

class BundleComposerPolicy < ApplicationPolicy
  def search?
    true
  end

  def product_details?
    true
  end

  def preview?
    user_context.can_write?
  end
end
