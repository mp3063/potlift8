# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user_context, :record

  def initialize(user_context, record)
    @user_context = user_context
    @record = record
  end

  def index?
    true
  end

  def show?
    true
  end

  def export?
    true
  end

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
