# frozen_string_literal: true

# Money is stored in cents (e.g. "4000"); people read and type "40,00".
# Convert only at the edges: views, forms and CSV. API and sync stay in cents.
module Cents
  class InvalidAmount < ArgumentError; end

  SYMBOLS = { "eur" => "€" }.freeze
  INPUT_FORMAT = /\A\d+(?:[.,]\d{1,2})?\z/

  module_function

  # 4000 => "40,00 €"
  def format(cents, currency: "eur")
    return nil if cents.blank?
    return cents.to_s unless whole?(cents)

    unit = SYMBOLS.fetch(currency.to_s.downcase, currency.to_s.upcase)
    ActiveSupport::NumberHelper.number_to_currency(
      cents.to_i / 100.0, unit: unit, separator: ",", delimiter: " ", format: "%n %u"
    )
  end

  # 4050 => "40,50" (pre-fills an input)
  def to_input(cents)
    return "" if cents.blank?
    return cents.to_s unless whole?(cents)

    ActiveSupport::NumberHelper.number_to_rounded(cents.to_i / 100.0, precision: 2, separator: ",")
  end

  # 123450 => "1234.50" (CSV)
  def to_decimal(cents)
    return nil if cents.blank?
    return cents.to_s unless whole?(cents)

    ActiveSupport::NumberHelper.number_to_rounded(cents.to_i / 100.0, precision: 2)
  end

  # "40,5" => 4050; spaces are thousands separators
  def parse(input)
    text = input.to_s.gsub(/\s/, "")
    return nil if text.empty?
    raise InvalidAmount, "#{input.to_s.strip} is not a valid amount (use e.g. 40,00 or 40.00)" unless text.match?(INPUT_FORMAT)

    (BigDecimal(text.tr(",", ".")) * 100).to_i
  end

  def whole?(cents)
    cents.is_a?(Integer) || cents.to_s.match?(/\A\d+\z/)
  end
end
