# frozen_string_literal: true

class StoragePolicy < ApplicationPolicy
  def inventory?
    true
  end
end
