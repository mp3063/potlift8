# frozen_string_literal: true

# Base policy with sensible defaults for all resources.
#
# Defaults:
#   - Read actions (index, show, export) → all authenticated users
#   - Write actions (create, update, reorder) → users with "write" scope
#   - Destructive actions (destroy) → admin only
#
# Override in resource-specific policies only where behavior differs.
#
class ApplicationPolicy
  attr_reader :user_context, :record

  def initialize(user_context, record)
    @user_context = user_context
    @record = record
  end

  # --- Read actions (all authenticated users) ---

  def index?
    true
  end

  def show?
    true
  end

  def export?
    true
  end

  # --- Write actions (require "write" scope) ---

  def new?
    create?
  end

  def create?
    user_context.can_write?
  end

  def edit?
    update?
  end

  def update?
    user_context.can_write?
  end

  def reorder?
    user_context.can_write?
  end

  # --- Destructive actions (admin only) ---

  def destroy?
    user_context.admin?
  end

  class Scope
    attr_reader :user_context, :scope

    def initialize(user_context, scope)
      @user_context = user_context
      @scope = scope
    end

    def resolve
      scope.all
    end
  end
end
