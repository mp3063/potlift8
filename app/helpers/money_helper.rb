# frozen_string_literal: true

# Money attribute values are stored in cents; these turn them into what people read and type.
module MoneyHelper
  # "4000" => "40,00 €"; a special price "amount,from,until" gets its date range appended.
  def attribute_display_value(attribute, raw_value, currency: "eur")
    return raw_value unless attribute.money? && raw_value.present?

    amount, from, till = special_price_parts(attribute, raw_value)
    formatted = Cents.format(amount, currency: currency)
    from.present? || till.present? ? "#{formatted} (#{from} – #{till})" : formatted
  end

  # "4050" => "40,50" to pre-fill an input; a special price keeps only its amount.
  def attribute_input_value(attribute, raw_value)
    return raw_value unless attribute.money?

    Cents.to_input(special_price_parts(attribute, raw_value).first)
  end

  private

  def special_price_parts(attribute, raw_value)
    attribute.view_format_special_price? ? raw_value.to_s.split(",", 3) : [ raw_value ]
  end
end
