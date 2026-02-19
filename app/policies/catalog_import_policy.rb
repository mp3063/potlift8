# frozen_string_literal: true

class CatalogImportPolicy < ApplicationPolicy
  def template?
    true
  end
end
