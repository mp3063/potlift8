# frozen_string_literal: true

class VariantPolicy < ApplicationPolicy
  def generate?
    user_context.can_write?
  end
end
