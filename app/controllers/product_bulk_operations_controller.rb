# frozen_string_literal: true

class ProductBulkOperationsController < ApplicationController
  def destroy
    authorize :product_bulk_operation, :destroy?
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

  def update_labels
    authorize :product_bulk_operation, :update_labels?
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

  def labels_for_products
    authorize :product_bulk_operation, :labels_for_products?
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

    assigned_to_any = products
                        .joins(:labels)
                        .distinct
                        .pluck("labels.id")

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
