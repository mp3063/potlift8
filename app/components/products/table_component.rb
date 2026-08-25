# frozen_string_literal: true

module Products
  class TableComponent < ViewComponent::Base
    def initialize(products:, pagy:, current_sort: nil, current_direction: nil, search_query: nil, has_filters: false)
      @products = products
      @pagy = pagy
      @current_sort = current_sort
      @current_direction = current_direction
      @search_query = search_query
      @has_filters = has_filters
    end

    private

    attr_reader :products, :pagy, :current_sort, :current_direction, :search_query, :has_filters

    def sort_link(column, label)
      direction = if current_sort == column
                    current_direction == "asc" ? "desc" : "asc"
      else
                    "asc"
      end

      link_to(
        products_path(sort: column, direction: direction),
        class: sort_link_classes(column),
        data: { turbo_frame: "products_table" }
      ) do
        content_tag(:span, label, class: "flex-1") +
        sort_icon(column)
      end
    end

    def sort_link_classes(column)
      base = "group inline-flex items-center justify-between w-full gap-x-2"

      if current_sort == column
        "#{base} text-blue-600 font-semibold"
      else
        "#{base} text-gray-700 hover:text-blue-600"
      end
    end

    def sort_icon(column)
      if current_sort == column
        if current_direction == "asc"
          chevron_down_icon
        else
          chevron_up_icon
        end
      else
        unsorted_icon
      end
    end

    def status_badge(product)
      helpers.product_status_badge(product)
    end

    def type_badge(product)
      helpers.product_type_badge(product)
    end

    def chevron_up_icon
      '<svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06-.02L10 8.832 6.29 12.77a.75.75 0 11-1.08-1.04l4.25-4.5a.75.75 0 011.08 0l4.25 4.5a.75.75 0 01-.02 1.06z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    def chevron_down_icon
      '<svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    def unsorted_icon
      '<svg class="h-4 w-4 opacity-40 group-hover:opacity-100 transition-opacity" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 3a.75.75 0 01.75.75v10.638l3.96-4.158a.75.75 0 111.08 1.04l-5.25 5.5a.75.75 0 01-1.08 0l-5.25-5.5a.75.75 0 111.08-1.04l3.96 4.158V3.75A.75.75 0 0110 3z" clip-rule="evenodd" />
        <path fill-rule="evenodd" d="M10 17a.75.75 0 01-.75-.75V5.612L5.29 9.77a.75.75 0 01-1.08-1.04l5.25-5.5a.75.75 0 011.08 0l5.25 5.5a.75.75 0 11-1.08 1.04l-3.96-4.158v10.638A.75.75 0 0110 17z" clip-rule="evenodd" opacity="0.3" />
      </svg>'.html_safe
    end

    def edit_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" />
      </svg>'.html_safe
    end

    def duplicate_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M7 3.5A1.5 1.5 0 018.5 2h3.879a1.5 1.5 0 011.06.44l3.122 3.12A1.5 1.5 0 0117 6.622V12.5a1.5 1.5 0 01-1.5 1.5h-1v-3.379a3 3 0 00-.879-2.121L10.5 5.379A3 3 0 008.379 4.5H7v-1z" />
        <path d="M4.5 6A1.5 1.5 0 003 7.5v9A1.5 1.5 0 004.5 18h7a1.5 1.5 0 001.5-1.5v-5.879a1.5 1.5 0 00-.44-1.06L9.44 6.439A1.5 1.5 0 008.378 6H4.5z" />
      </svg>'.html_safe
    end

    def trash_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    def plus_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
      </svg>'.html_safe
    end

    def expandable_product?(product)
      if product.product_type_bundle?
        product.bundle_variants.any?
      elsif product.product_type_configurable?
        product.subproducts.any?
      else
        false
      end
    end

    def expandable_children(product)
      if product.product_type_bundle?
        product.bundle_variants.to_a
      elsif product.product_type_configurable?
        product.subproducts.to_a
      else
        []
      end
    end

    def children_label(product)
      if product.product_type_bundle?
        "variants"
      elsif product.product_type_configurable?
        "variants"
      else
        "items"
      end
    end

    def view_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M10 12.5a2.5 2.5 0 100-5 2.5 2.5 0 000 5z" />
        <path fill-rule="evenodd" d="M.664 10.59a1.651 1.651 0 010-1.186A10.004 10.004 0 0110 3c4.257 0 7.893 2.66 9.336 6.41.147.381.146.804 0 1.186A10.004 10.004 0 0110 17c-4.257 0-7.893-2.66-9.336-6.41zM14 10a4 4 0 11-8 0 4 4 0 018 0z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    def package_icon
      '<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
      </svg>'.html_safe
    end

    def search_icon
      '<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>'.html_safe
    end

    def empty_state_title
      if has_filters || search_query.present?
        "No products found"
      else
        "No products"
      end
    end

    def empty_state_description
      if search_query.present?
        "No products match your search for \"#{search_query}\". Try adjusting your search terms or filters."
      elsif has_filters
        "No products match the current filters. Try adjusting your filters or clearing them."
      else
        "Get started by creating a new product."
      end
    end

    def empty_state_icon
      if has_filters || search_query.present?
        search_icon
      else
        package_icon
      end
    end

    def show_new_product_button?
      !has_filters && search_query.blank?
    end
  end
end
