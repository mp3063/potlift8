# frozen_string_literal: true

# Features:
# - Multi-scope search (all, products, storage, attributes, labels, catalogs)
# - Recent searches stored in Redis (last 10 per user, 30-day expiry)
# - Scoped to current company (multi-tenant)
# - HTML and JSON response formats
# - Eager loading to prevent N+1 queries
class SearchController < ApplicationController
  skip_after_action :verify_authorized

  def index
    @query = params[:q]
    @scope = params[:scope] || "all"

    if @query.blank?
      @results = {}
      respond_to do |format|
        format.html
        format.json { render json: @results }
      end
      return
    end

    sanitized_query = sanitize_query(@query)

    @results = case @scope
    when "all"
                 search_all(sanitized_query)
    when "products"
                 { products: search_products(sanitized_query) }
    when "storage"
                 { storage: search_storage(sanitized_query) }
    when "attributes"
                 { attributes: search_attributes(sanitized_query) }
    when "labels"
                 { labels: search_labels(sanitized_query) }
    when "catalogs"
                 { catalogs: search_catalogs(sanitized_query) }
    else
                 {}
    end

    store_recent_search(@query) if results_found?(@results)

    respond_to do |format|
      format.html
      format.json { render json: format_json_response(@results) }
    end
  end

  def recent
    recent_searches = Rails.cache.read(recent_searches_cache_key) || []
    render json: recent_searches
  end

  private

  def search_all(query)
    {
      products: search_products(query, limit: 5),
      storage: search_storage(query, limit: 5),
      attributes: search_attributes(query, limit: 5),
      labels: search_labels(query, limit: 5),
      catalogs: search_catalogs(query, limit: 5)
    }
  end

  # Uses PostgreSQL trigram indexes for fast ILIKE searches (10-50x faster)
  def search_products(query, limit: 50)
    current_potlift_company.products
      .with_search_associations # Eager load labels and attributes to prevent N+1
      .where(
        "name ILIKE :query OR sku ILIKE :query OR info->>'description' ILIKE :query",
        query: "%#{query}%"
      )
      .order(product_status: :asc, name: :asc)
      .limit(limit)
  end

  def search_storage(query, limit: 50)
    current_potlift_company.storages
      .where(
        "name ILIKE :query OR code ILIKE :query OR info->>'address' ILIKE :query",
        query: "%#{query}%"
      )
      .where(storage_status: :active)
      .order(:name)
      .limit(limit)
  end

  def search_attributes(query, limit: 50)
    current_potlift_company.product_attributes
      .where(
        "name ILIKE :query OR code ILIKE :query",
        query: "%#{query}%"
      )
      .order(:attribute_position)
      .limit(limit)
  end

  def search_labels(query, limit: 50)
    current_potlift_company.labels
      .where(
        "name ILIKE :query OR full_name ILIKE :query",
        query: "%#{query}%"
      )
      .order(:label_positions)
      .limit(limit)
  end

  def search_catalogs(query, limit: 50)
    current_potlift_company.catalogs
      .where(
        "name ILIKE :query OR code ILIKE :query",
        query: "%#{query}%"
      )
      .order(:name)
      .limit(limit)
  end

  def store_recent_search(query)
    cache_key = recent_searches_cache_key
    recent = Rails.cache.read(cache_key) || []

    recent.unshift(query)
    recent = recent.uniq.first(10)

    Rails.cache.write(cache_key, recent, expires_in: 30.days)
  end

  def recent_searches_cache_key
    "recent_searches:#{current_user[:id]}"
  end

  # Sanitize query for SQL ILIKE to prevent SQL injection
  def sanitize_query(query)
    query.to_s.gsub(/[%_\\]/) { |char| "\\#{char}" }
  end

  def results_found?(results)
    return false if results.blank?

    results.values.any? { |scope_results| scope_results.present? && scope_results.any? }
  end

  def format_json_response(results)
    formatted = {}

    results.each do |scope, records|
      formatted[scope] = case scope
      when :products
                           format_products_json(records)
      when :storage
                           format_storage_json(records)
      when :attributes
                           format_attributes_json(records)
      when :labels
                           format_labels_json(records)
      when :catalogs
                           format_catalogs_json(records)
      else
                           []
      end
    end

    formatted
  end

  def format_products_json(products)
    products.map do |product|
      {
        id: product.id,
        sku: product.sku,
        name: product.name,
        product_type: product.product_type,
        product_status: product.product_status,
        url: product_path(product)
      }
    end
  end

  def format_storage_json(storages)
    storages.map do |storage|
      {
        id: storage.id,
        code: storage.code,
        name: storage.name,
        storage_type: storage.storage_type,
        url: storage_path(storage)
      }
    end
  end

  def format_attributes_json(attributes)
    attributes.map do |attribute|
      {
        id: attribute.id,
        code: attribute.code,
        name: attribute.name,
        pa_type: attribute.pa_type,
        url: product_attribute_path(attribute)
      }
    end
  end

  def format_labels_json(labels)
    labels.map do |label|
      {
        id: label.id,
        code: label.code,
        name: label.name,
        full_name: label.full_name,
        label_type: label.label_type,
        url: label_path(label)
      }
    end
  end

  def format_catalogs_json(catalogs)
    catalogs.map do |catalog|
      {
        id: catalog.id,
        code: catalog.code,
        name: catalog.name,
        catalog_type: catalog.catalog_type,
        currency_code: catalog.currency_code,
        url: catalog_path(catalog)
      }
    end
  end
end
