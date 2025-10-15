# frozen_string_literal: true

module Products
  # Products table component with sorting and pagination
  #
  # Renders a comprehensive product listing table with sortable columns,
  # status/type badges, action buttons, and pagination. The table uses
  # Turbo Frames for dynamic updates without full page reloads.
  #
  # **Features:**
  # - Sortable columns (SKU, Name, Created At) with visual indicators
  # - Status badges (active, draft, discontinued, etc.)
  # - Product type badges (sellable, configurable, bundle)
  # - Action buttons (Edit, Duplicate, Delete)
  # - Turbo Frame integration for smooth updates
  # - Empty state with call-to-action
  # - Mobile responsive design
  # - Pagination with Pagy
  #
  # **Accessibility:**
  # - Semantic table structure
  # - ARIA labels for icon buttons
  # - Screen reader friendly sort indicators
  # - Keyboard navigation support
  # - Focus indicators
  #
  # **Sortable Columns:**
  # - SKU (sku)
  # - Product Name (name)
  # - Created At (created_at)
  #
  # **Dependencies:**
  # - ProductsHelper for badge rendering
  # - Pagy for pagination
  # - Turbo for dynamic updates
  #
  # @example Basic usage
  #   <%= render Products::TableComponent.new(
  #     products: @products,
  #     pagy: @pagy
  #   ) %>
  #
  # @example With sorting
  #   <%= render Products::TableComponent.new(
  #     products: @products,
  #     pagy: @pagy,
  #     current_sort: 'sku',
  #     current_direction: 'asc'
  #   ) %>
  #
  # @example Empty products list
  #   <%= render Products::TableComponent.new(
  #     products: Product.none,
  #     pagy: pagy(Product.none)
  #   ) %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  # @see ProductsHelper Badge rendering helpers
  #
  class TableComponent < ViewComponent::Base
    # Initialize a new products table component
    #
    # @param products [ActiveRecord::Relation] Collection of products to display
    # @param pagy [Pagy] Pagy pagination object
    # @param current_sort [String, nil] Currently sorted column (sku, name, created_at)
    # @param current_direction [String, nil] Current sort direction (asc, desc)
    #
    # @example
    #   TableComponent.new(
    #     products: Product.where(product_status: :active),
    #     pagy: pagy(Product.all),
    #     current_sort: 'sku',
    #     current_direction: 'asc'
    #   )
    #
    # @return [TableComponent]
    def initialize(products:, pagy:, current_sort: nil, current_direction: nil)
      @products = products
      @pagy = pagy
      @current_sort = current_sort
      @current_direction = current_direction
    end

    private

    attr_reader :products, :pagy, :current_sort, :current_direction

    # Generates a sortable column header link
    #
    # Creates a link that toggles sort direction when clicked. If the column
    # is already sorted, clicking again reverses the direction. Uses Turbo Frame
    # to update the table without full page reload.
    #
    # @param column [String] The column name to sort by (sku, name, created_at)
    # @param label [String] The display text for the column header
    #
    # @return [String] HTML link element with sort functionality
    #
    # @example
    #   sort_link('sku', 'Product SKU')
    #   # => <a href="/products?sort=sku&direction=asc" data-turbo-frame="products_table">Product SKU</a>
    def sort_link(column, label)
      direction = if current_sort == column
                    current_direction == 'asc' ? 'desc' : 'asc'
                  else
                    'asc'
                  end

      link_to(
        label,
        products_path(sort: column, direction: direction),
        class: sort_link_classes(column),
        data: { turbo_frame: 'products_table' }
      )
    end

    # Builds CSS classes for sort link based on active state
    #
    # Applies different styling for the currently sorted column versus
    # sortable but not active columns.
    #
    # @param column [String] The column name
    #
    # @return [String] CSS class string with appropriate styling
    def sort_link_classes(column)
      base = "group inline-flex items-center gap-x-1"

      if current_sort == column
        "#{base} text-blue-600 font-semibold"
      else
        "#{base} text-gray-700 hover:text-blue-600"
      end
    end

    # Generates sort direction icon (chevron up/down)
    #
    # Returns appropriate icon based on current sort direction.
    # Only shown for the currently sorted column.
    #
    # @param column [String] The column name
    #
    # @return [String, nil] SVG icon HTML or nil if column not sorted
    def sort_icon(column)
      return unless current_sort == column

      if current_direction == 'asc'
        chevron_up_icon
      else
        chevron_down_icon
      end
    end

    # Renders product status badge
    #
    # Delegates to ProductsHelper for consistent badge styling across the app.
    #
    # @param product [Product] The product instance
    #
    # @return [String] HTML badge component
    def status_badge(product)
      helpers.product_status_badge(product)
    end

    # Renders product type badge
    #
    # Delegates to ProductsHelper for consistent badge styling across the app.
    #
    # @param product [Product] The product instance
    #
    # @return [String] HTML badge component
    def type_badge(product)
      helpers.product_type_badge(product)
    end

    # Chevron up icon SVG (ascending sort indicator)
    #
    # @return [String] HTML-safe SVG markup
    def chevron_up_icon
      '<svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M14.77 12.79a.75.75 0 01-1.06-.02L10 8.832 6.29 12.77a.75.75 0 11-1.08-1.04l4.25-4.5a.75.75 0 011.08 0l4.25 4.5a.75.75 0 01-.02 1.06z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    # Chevron down icon SVG
    def chevron_down_icon
      '<svg class="h-4 w-4" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    # Edit icon SVG
    def edit_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" />
      </svg>'.html_safe
    end

    # Duplicate icon SVG
    def duplicate_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M7 3.5A1.5 1.5 0 018.5 2h3.879a1.5 1.5 0 011.06.44l3.122 3.12A1.5 1.5 0 0117 6.622V12.5a1.5 1.5 0 01-1.5 1.5h-1v-3.379a3 3 0 00-.879-2.121L10.5 5.379A3 3 0 008.379 4.5H7v-1z" />
        <path d="M4.5 6A1.5 1.5 0 003 7.5v9A1.5 1.5 0 004.5 18h7a1.5 1.5 0 001.5-1.5v-5.879a1.5 1.5 0 00-.44-1.06L9.44 6.439A1.5 1.5 0 008.378 6H4.5z" />
      </svg>'.html_safe
    end

    # Trash icon SVG
    def trash_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10.23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 002.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34.06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    # Plus icon SVG
    def plus_icon
      '<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
      </svg>'.html_safe
    end

    # Package icon SVG (for empty state)
    def package_icon
      '<svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
      </svg>'.html_safe
    end
  end
end
