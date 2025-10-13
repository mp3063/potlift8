# frozen_string_literal: true

# Search controller
#
# Handles global search across products, storages, attributes, labels, and catalogs
#
class SearchController < ApplicationController
  # GET /search
  # Global search
  #
  # @param q [String] Search query
  def index
    @query = params[:q]

    if @query.present?
      # TODO: Implement full-text search across models
      # Expected implementation:
      # 1. Search products by SKU, name, description
      # 2. Search storages by code, name
      # 3. Search attributes by code, name
      # 4. Search labels by name
      # 5. Search catalogs by code, name
      # 6. Return results grouped by model type

      @results = {
        products: [],
        storages: [],
        attributes: [],
        labels: [],
        catalogs: []
      }
    else
      @results = {}
    end
  end
end
