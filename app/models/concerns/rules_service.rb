# Available rules:
# - positive: Value must be a positive integer (> 0)
# - not_null: Value must be present
module RulesService
  def positive(value)
    return false unless is_num?(value)
    value.to_i > 0
  end

  def not_null(value)
    value.present?
  end

  private

  def is_num?(str)
    !!Integer(str)
  rescue ArgumentError, TypeError
    false
  end
end
