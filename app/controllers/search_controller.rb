# frozen_string_literal: true

# SearchController
#
# Global search controller with multi-scope search functionality.
# Searches across products, storages, product attributes, labels, and catalogs.
#
# Features:
# - Multi-scope search (all, products, storage, attributes, labels, catalogs)
# - Recent searches stored in Redis (last 10 per user, 30-day expiry)
# - Scoped to current company (multi-tenant)
# - HTML and JSON response formats
# - Eager loading to prevent N+1 queries
#
# Routes:
# - GET /search?q=query&scope=all|products|storage|attributes|labels|catalogs
# - GET /search/recent
#
class SearchController < ApplicationController
  # GET /search
  # Performs multi-scope search based on query and scope parameters
  #
  # @param q [String] Search query (required)
  # @param scope [String] Search scope: all, products, storage, attributes, labels, catalogs (default: all)
  #
  # @example
  #   GET /search?q=iPhone&scope=products
  #   GET /search?q=warehouse&scope=storage
  #   GET /search?q=price&scope=all
  #
  def index
    @query = params[:q]
    @scope = params[:scope] || "all"

    # Return empty results if no query provided
    if @query.blank?
      @results = {}
      respond_to do |format|
        format.html
        format.json { render json: @results }
      end
      return
    end

    # Sanitize query for SQL ILIKE
    sanitized_query = sanitize_query(@query)

    # Perform search based on scope
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

    # Store recent search if results found
    store_recent_search(@query) if results_found?(@results)

    respond_to do |format|
      format.html
      format.json { render json: format_json_response(@results) }
    end
  end

  # GET /search/recent
  # Returns recent searches for the current user
  #
  # @return [Array<String>] Array of recent search queries (max 10)
  #
  # @example
  #   GET /search/recent
  #   # => ["iPhone", "warehouse", "price"]
  #
  def recent
    recent_searches = Rails.cache.read(recent_searches_cache_key) || []
    render json: recent_searches
  end

  private

  # Search all scopes with limited results (5 per scope)
  #
  # @param query [String] Sanitized search query
  # @return [Hash] Hash with search results for each scope
  #
  def search_all(query)
    {
      products: search_products(query, limit: 5),
      storage: search_storage(query, limit: 5),
      attributes: search_attributes(query, limit: 5),
      labels: search_labels(query, limit: 5),
      catalogs: search_catalogs(query, limit: 5)
    }
  end

  # Search products by name, SKU, or description
  #
  # Uses PostgreSQL trigram indexes for fast ILIKE searches (10-50x faster)
  #
  # @param query [String] Sanitized search query
  # @param limit [Integer] Maximum results to return (default: 50)
  # @return [ActiveRecord::Relation] Product search results
  #
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

  # Search storages by name, code, or address
  #
  # @param query [String] Sanitized search query
  # @param limit [Integer] Maximum results to return (default: 50)
  # @return [ActiveRecord::Relation] Storage search results
  #
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

  # Search product attributes by name or code
  #
  # @param query [String] Sanitized search query
  # @param limit [Integer] Maximum results to return (default: 50)
  # @return [ActiveRecord::Relation] Product attribute search results
  #
  def search_attributes(query, limit: 50)
    current_potlift_company.product_attributes
      .where(
        "name ILIKE :query OR code ILIKE :query",
        query: "%#{query}%"
      )
      .order(:attribute_position)
      .limit(limit)
  end

  # Search labels by name
  #
  # @param query [String] Sanitized search query
  # @param limit [Integer] Maximum results to return (default: 50)
  # @return [ActiveRecord::Relation] Label search results
  #
  def search_labels(query, limit: 50)
    current_potlift_company.labels
      .where(
        "name ILIKE :query OR full_name ILIKE :query",
        query: "%#{query}%"
      )
      .order(:label_positions)
      .limit(limit)
  end

  # Search catalogs by name or code
  #
  # @param query [String] Sanitized search query
  # @param limit [Integer] Maximum results to return (default: 50)
  # @return [ActiveRecord::Relation] Catalog search results
  #
  def search_catalogs(query, limit: 50)
    current_potlift_company.catalogs
      .where(
        "name ILIKE :query OR code ILIKE :query",
        query: "%#{query}%"
      )
      .order(:name)
      .limit(limit)
  end

  # Store recent search in Redis cache
  #
  # Maintains last 10 unique searches per user with 30-day expiration.
  #
  # @param query [String] Search query to store
  # @return [void]
  #
  def store_recent_search(query)
    cache_key = recent_searches_cache_key
    recent = Rails.cache.read(cache_key) || []

    # Add to beginning, remove duplicates, keep last 10
    recent.unshift(query)
    recent = recent.uniq.first(10)

    Rails.cache.write(cache_key, recent, expires_in: 30.days)
  end

  # Generate Redis cache key for recent searches
  #
  # @return [String] Cache key scoped to current user
  #
  def recent_searches_cache_key
    "recent_searches:#{current_user[:id]}"
  end

  # Sanitize query for SQL ILIKE to prevent SQL injection
  #
  # Escapes special characters: %, _, \
  #
  # @param query [String] Raw search query
  # @return [String] Sanitized query
  #
  def sanitize_query(query)
    query.to_s.gsub(/[%_\\]/) { |char| "\\#{char}" }
  end

  # Check if any results were found
  #
  # @param results [Hash] Search results hash
  # @return [Boolean] true if any scope has results
  #
  def results_found?(results)
    return false if results.blank?

    results.values.any? { |scope_results| scope_results.present? && scope_results.any? }
  end

  # Format search results for JSON response
  #
  # Converts ActiveRecord relations to JSON-compatible hashes with
  # only the necessary fields for the frontend.
  #
  # @param results [Hash] Search results hash
  # @return [Hash] Formatted JSON response
  #
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

  # Format products for JSON response
  #
  # @param products [ActiveRecord::Relation] Product records
  # @return [Array<Hash>] Formatted product data
  #
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

  # Format storages for JSON response
  #
  # @param storages [ActiveRecord::Relation] Storage records
  # @return [Array<Hash>] Formatted storage data
  #
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

  # Format product attributes for JSON response
  #
  # @param attributes [ActiveRecord::Relation] Product attribute records
  # @return [Array<Hash>] Formatted attribute data
  #
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

  # Format labels for JSON response
  #
  # @param labels [ActiveRecord::Relation] Label records
  # @return [Array<Hash>] Formatted label data
  #
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

  # Format catalogs for JSON response
  #
  # @param catalogs [ActiveRecord::Relation] Catalog records
  # @return [Array<Hash>] Formatted catalog data
  #
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
