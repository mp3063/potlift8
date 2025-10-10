require 'active_support/concern'

# AttributeValues Module
#
# Provides validation and value handling logic for ProductAttributeValue records.
# This concern handles:
# - Validation of values against ProductAttribute rules
# - Value formatting based on view_format
# - Storage of complex attribute values in info jsonb
#
# Usage:
#   class ProductAttributeValue < ApplicationRecord
#     include AttributeValues
#   end
#
module AttributeValues
  extend ActiveSupport::Concern

  included do
    # Validate attribute value against ProductAttribute rules before save
    validate do |av|
      if (av.ready? || !av.new_record?) && broken_rule.present?
        av.errors.add(:base, "You can't give this value to #{av.product_attribute.name} as it must be #{broken_rule}")
      end
    end
  end

  # Stores value from form parameters based on view_format
  #
  # Handles different view formats:
  # - customer_group_price: Stores customer-specific prices in info hash
  # - special_price: Stores amount and date range in info hash
  # - default: Stores in value column
  #
  # @param params [Hash] Form parameters containing the value(s)
  # @return [String, nil] Formatted display value or nil
  #
  def store_value_from_params(params)
    self.info ||= {}

    if product_attribute.view_format_customer_group_price?
      self.info['customer_group_prices'] ||= {}
      params.keys.select { |k| k.to_s.match?(/customer_group_.+/) }.each do |customer_group_key_base|
        customer_group_key = customer_group_key_base.to_s.gsub('customer_group_', '')
        if params[customer_group_key_base].to_i > 0
          self.info['customer_group_prices'] = {} if self.info['customer_group_prices'].blank?
          self.info['customer_group_prices'][customer_group_key] = params[customer_group_key_base].to_i
        else
          self.info['customer_group_prices'].delete(customer_group_key)
        end
      end

      # Return formatted display value
      info['customer_group_prices'].keys.sum('') do |customer_group_key|
        price = ActionController::Base.helpers.number_to_currency(
          (info.to_h['customer_group_prices'].to_h[customer_group_key].to_f / 100),
          unit: "€", separator: ",", delimiter: " ", format: "%n %u"
        )
        "<strong>#{customer_group_key.gsub('customer_group_', '')}: </strong><span>#{price}</span>"
      end.html_safe

    elsif product_attribute.view_format_special_price?
      raise ArgumentError, "Special price amount must be positive" unless params['special-price-amount'].to_i > 0
      raise ArgumentError, "Special price from date is invalid" unless params['special-price-from'].to_date.present?
      raise ArgumentError, "Special price until date is invalid" unless params['special-price-until'].to_date.present?

      self.info['special_price'] ||= {}
      self.info['special_price']['amount'] = params['special-price-amount'].to_i
      self.info['special_price']['from'] = params['special-price-from'].to_date
      self.info['special_price']['until'] = params['special-price-until'].to_date

      price = ActionController::Base.helpers.number_to_currency(
        (info['special_price']['amount'].to_f / 100),
        unit: "€", separator: ",", delimiter: " ", format: "%n %u"
      )
      "#{price} (#{self.info['special_price']['from']} - #{self.info['special_price']['until']})"

    else
      self.value = params[:value]
    end
  end

  # Stores value from CSV import based on view_format
  #
  # @param value [String] CSV value to parse and store
  # @raise [ArgumentError] if value format is invalid
  #
  def store_value_from_import(value)
    self.info ||= {}

    if product_attribute.view_format_special_price?
      raise ArgumentError, "Special price value cannot be blank" unless value.present?

      special_price = value.split(',')
      raise ArgumentError, "Special price must have 3 parts: amount,from,until" unless special_price.present? && special_price.size == 3
      raise ArgumentError, "Special price amount must be positive" unless special_price[0].to_i > 0
      raise ArgumentError, "Special price from date is invalid" unless special_price[1].to_date.present?
      raise ArgumentError, "Special price until date is invalid" unless special_price[2].to_date.present?

      self.info['special_price'] ||= {}
      self.info['special_price']['amount'] = special_price[0]
      self.info['special_price']['from'] = special_price[1]
      self.info['special_price']['until'] = special_price[2]

    elsif product_attribute.view_format_customer_group_price?
      raise ArgumentError, "Customer group price value cannot be blank" unless value.present?

      self.info['customer_group_prices'] ||= {}
      value.split(',').each do |customer_price|
        customer = customer_price.split(':')[0]
        price = customer_price.split(':')[1]
        info['customer_group_prices'][customer] = price
      end

    else
      self.value = value
    end
  end

  # Checks if attribute value passes all validation rules
  # Sets the ready flag before save
  #
  def check_readiness
    self.ready = broken_rule.blank?
  end

  # Finds the first broken rule for the current value
  #
  # @return [String, nil] Name of broken rule or nil if all rules pass
  #
  def broken_rule
    return nil unless product_attribute.rules.present?

    product_attribute.rules.each do |rule|
      return rule if product_attribute.send(rule, value) == false
    end
    nil
  end

  # Returns the value, handling custom view formats
  #
  # For custom view formats (special_price, customer_group_price),
  # reconstructs the value from info jsonb storage
  #
  # @return [String] The attribute value
  #
  def value
    return super unless product_attribute.patype_custom?

    if product_attribute.view_format_special_price? && self.info.to_h['special_price'].present?
      return "#{self.info.to_h['special_price'].to_h['amount']},#{self.info.to_h['special_price'].to_h['from']},#{self.info.to_h['special_price'].to_h['until']}"
    end

    if product_attribute.view_format_customer_group_price? && self.info.to_h['customer_group_prices'].present?
      return self.info.to_h['customer_group_prices'].to_h.map { |k, v| "#{k}:#{v}" }.join(',')
    end

    super
  end

  # Returns related products for view_format_related_products
  #
  # @return [ActiveRecord::Relation<Product>] Related products
  #
  def related_products
    related_products = self.info.to_h['related_products'].to_a
    Product.where(sku: related_products)
  end

  # Checks if attribute has localized values
  #
  # @return [Boolean] true if localized values exist
  #
  def localized_values?
    info.to_h['localized_value'].to_h.values.any? { |x| x.present? }
  end

  private

  # Propagates changes to parent product (touches updated_at)
  def propagate_change
    product.touch if product.present?
  end
end
