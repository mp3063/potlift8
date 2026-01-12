# frozen_string_literal: true

# Product Bulk Operations Controller
#
# Handles bulk operations for products, extracted from ProductsController
# to follow the Single Responsibility Principle.
#
# Actions:
# - POST /products/bulk/destroy - Bulk delete multiple products
# - POST /products/bulk/update_labels - Bulk add/remove labels from products
# - GET /products/bulk/labels_for_products - Get labels assigned to selected products
#
class ProductBulkOperationsController < ApplicationController
  # POST /products/bulk/destroy
  def destroy
    product_ids = params[:product_ids] || []

    if product_ids.empty?
      redirect_to products_path, alert: "No products selected."
      return
    end

    products = current_potlift_company.products
                 .where(id: product_ids)
                 .includes(:product_attribute_values, :labels, :inventories,
                           :product_assets, :catalog_items,
                           :product_configurations_as_super, :product_configurations_as_sub,
                           images_attachments: :blob)

    successful_count = 0
    failed_products = []

    products.each do |product|
      if product.destroy
        successful_count += 1
      else
        failed_products << "#{product.sku} (#{product.errors.full_messages.join(', ')})"
      end
    end

    if failed_products.any?
      redirect_to products_path,
                  alert: "#{successful_count} #{'product'.pluralize(successful_count)} deleted. Failed to delete: #{failed_products.join('; ')}"
    else
      redirect_to products_path,
                  notice: "#{successful_count} #{'product'.pluralize(successful_count)} deleted successfully."
    end
  end

  # POST /products/bulk/update_labels
  def update_labels
    product_ids = params[:product_ids] || []
    label_ids = (params[:label_ids] || []).compact.map(&:to_i)
    action_type = params[:action_type] || "add"

    if product_ids.empty?
      redirect_to products_path, alert: "No products selected."
      return
    end

    if label_ids.empty?
      redirect_to products_path, alert: "No labels selected."
      return
    end

    successful_count = 0
    failed_products = []

    ActiveRecord::Base.transaction do
      current_potlift_company.products
        .where(id: product_ids)
        .includes(:labels, :catalogs, :superproducts)
        .find_each do |product|
        begin
          if action_type == "remove"
            product.label_ids = product.label_ids - label_ids
          else
            product.label_ids = (product.label_ids + label_ids).uniq
          end

          if product.save
            successful_count += 1
          else
            failed_products << "#{product.sku} (#{product.errors.full_messages.join(', ')})"
          end
        rescue StandardError => e
          failed_products << "#{product.sku} (#{e.message})"
        end
      end

      raise ActiveRecord::Rollback if failed_products.any?
    end

    action_text = action_type == "remove" ? "removed from" : "added to"
    if failed_products.any?
      redirect_to products_path,
                  alert: "Failed to update labels. Errors: #{failed_products.join('; ')}"
    else
      redirect_to products_path,
                  notice: "Labels #{action_text} #{successful_count} #{'product'.pluralize(successful_count)} successfully."
    end
  rescue StandardError => e
    redirect_to products_path, alert: "Failed to update labels: #{e.message}"
  end

  # GET /products/bulk/labels_for_products
  # Returns JSON with:
  # - assigned_to_any: label IDs assigned to ANY selected product (for remove mode)
  # - assigned_to_all: label IDs assigned to ALL selected products (for add mode exclusion)
  def labels_for_products
    product_ids = params[:product_ids] || []

    if product_ids.empty?
      render json: { assigned_to_any: [], assigned_to_all: [] }
      return
    end

    products = current_potlift_company.products.where(id: product_ids)
    product_count = products.count

    if product_count == 0
      render json: { assigned_to_any: [], assigned_to_all: [] }
      return
    end

    # Get all label IDs assigned to ANY of the selected products (union)
    assigned_to_any = products
                        .joins(:labels)
                        .distinct
                        .pluck("labels.id")

    # Get label IDs assigned to ALL selected products (intersection)
    # These are labels where the count of products equals the total product count
    assigned_to_all = ProductLabel
                        .where(product_id: products.select(:id))
                        .group(:label_id)
                        .having("COUNT(DISTINCT product_id) = ?", product_count)
                        .pluck(:label_id)

    render json: {
      assigned_to_any: assigned_to_any,
      assigned_to_all: assigned_to_all
    }
  end
end
