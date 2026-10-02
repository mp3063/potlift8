# New variants copy the parent's value for subproduct_mandatory attributes (VariantAttributeInheritance)
class FlagWeightAndPurchasePriceSubproductMandatory < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE product_attributes SET subproduct_mandatory = TRUE WHERE code IN ('weight', 'purchase_price')
    SQL
  end

  def down
    execute <<~SQL
      UPDATE product_attributes SET subproduct_mandatory = FALSE WHERE code IN ('weight', 'purchase_price')
    SQL
  end
end
