# frozen_string_literal: true

class ProductAttributePolicy < ApplicationPolicy
  def validate_code?
    true
  end
end
