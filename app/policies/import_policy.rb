# frozen_string_literal: true

class ImportPolicy < ApplicationPolicy
  def download_template?
    true
  end

  def progress?
    true
  end

  def download_errors?
    true
  end
end
