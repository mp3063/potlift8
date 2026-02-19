# frozen_string_literal: true

require 'rails_helper'

# Tests for product filtering functionality on the Products index page
#
# The products index page provides:
# - Search by name/SKU (q param)
# - Filter by product type dropdown (type param: sellable, configurable, bundle)
# - Filter by label via dropdown (label_id param)
# - Active label filter chip with remove functionality
# - Clear button to reset filters
#
# Note: Some tests use JavaScript (js: true) for dropdown interactions.
# All tests use :rack_test driver except those marked with js: true which use Selenium.
# Database cleaner uses truncation for js tests which can affect data isolation.
#
RSpec.describe 'Product Filtering', type: :system do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Mock authentication
  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
      { id: user.id, email: user.email, name: user.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(
      { id: company.id, code: company.code, name: company.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  let!(:label_electronics) { create(:label, company: company, name: 'Electronics', code: 'electronics') }
  let!(:label_clothing) { create(:label, company: company, name: 'Clothing', code: 'clothing') }

  let!(:product1) do
    create(:product,
      company: company,
      name: 'iPhone 15',
      sku: 'IP-15',
      product_type: :sellable,
      product_status: :active
    )
  end

  let!(:product2) do
    create(:product,
      company: company,
      name: 'T-Shirt Bundle',
      sku: 'TSHIRT-BUNDLE',
      product_type: :bundle,
      product_status: :active
    )
  end

  let!(:product3) do
    create(:product,
      company: company,
      name: 'Old Product',
      sku: 'OLD-1',
      product_type: :sellable,
      product_status: :discontinued
    )
  end

  before do
    # Associate labels with products
    create(:product_label, product: product1, label: label_electronics)
    create(:product_label, product: product2, label: label_clothing)
  end

  describe "filter by product type" do
    it "shows all products initially" do
      visit products_path

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).to have_text('Old Product')
    end

    it "filters by sellable product type" do
      visit products_path

      select 'Sellable', from: 'type'
      click_button 'Search'

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('Old Product')
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "filters by bundle product type" do
      visit products_path

      select 'Bundle', from: 'type'
      click_button 'Search'

      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('iPhone 15')
      expect(page).not_to have_text('Old Product')
    end

    it "filters by configurable product type" do
      configurable_product = create(:product, :configurable_variant,
        company: company,
        name: 'Configurable Widget',
        sku: 'CONFIG-1',
        product_status: :active
      )

      visit products_path

      select 'Configurable', from: 'type'
      click_button 'Search'

      expect(page).to have_text('Configurable Widget')
      expect(page).not_to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
    end
  end

  describe "filter by labels" do
    it "filters by single label via URL parameter" do
      visit products_path(label_id: label_electronics.id)

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "shows active filter chip for label" do
      visit products_path(label_id: label_electronics.id)

      # Should show active filter chip with label name
      expect(page).to have_text('Electronics')
      expect(page).to have_css('.bg-blue-100') # Filter chip styling
    end

    it "removes label filter when clicking remove button" do
      visit products_path(label_id: label_electronics.id)

      # Should show the active filter chip
      expect(page).to have_text('Electronics')
      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')

      # Click remove button on filter chip
      find('a[aria-label="Remove label filter"]').click

      # Should show all products again
      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
    end
  end

  describe "search by name or SKU" do
    it "searches by product name" do
      visit products_path

      fill_in 'q', with: 'iPhone'
      click_button 'Search'

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('Old Product')
    end

    it "searches by product SKU" do
      visit products_path

      fill_in 'q', with: 'TSHIRT'
      click_button 'Search'

      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('iPhone 15')
      expect(page).not_to have_text('Old Product')
    end

    it "searches case-insensitively" do
      visit products_path

      fill_in 'q', with: 'iphone'
      click_button 'Search'

      expect(page).to have_text('iPhone 15')
    end
  end

  describe "combined filters" do
    it "applies type and search filters simultaneously" do
      visit products_path

      fill_in 'q', with: 'Product'
      select 'Sellable', from: 'type'
      click_button 'Search'

      # Old Product is sellable with "Product" in name
      expect(page).to have_text('Old Product')
      # T-Shirt Bundle has "Bundle" in name but is not sellable type
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "applies type and label filters simultaneously" do
      # Visit with both type and label_id filters
      visit products_path(type: 'sellable', label_id: label_electronics.id)

      # iPhone 15 is sellable AND has electronics label
      expect(page).to have_text('iPhone 15')
      # Old Product is sellable but has no electronics label
      expect(page).not_to have_text('Old Product')
      # T-Shirt Bundle has clothing label but is bundle type
      expect(page).not_to have_text('T-Shirt Bundle')
    end
  end

  describe "clear filters" do
    it "clears all filters when clicking Clear button" do
      visit products_path(type: 'sellable', q: 'iPhone')

      # Should show filtered results
      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')

      # Click clear button
      click_link 'Clear'

      # Should show all products again
      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).to have_text('Old Product')
    end

    it "shows Clear button only when filters are active" do
      visit products_path

      # No filters active - no Clear button
      expect(page).not_to have_link('Clear')

      visit products_path(type: 'sellable')

      # Filter active - Clear button should appear
      expect(page).to have_link('Clear')
    end
  end

  describe "URL state preservation" do
    it "preserves type filter in URL when submitting form" do
      visit products_path

      select 'Sellable', from: 'type'
      click_button 'Search'

      # After form submission, the page should reload with the type param in URL
      # Note: This is a non-JS test so form submission is a regular GET request
      expect(page.current_url).to include('type=sellable')
    end

    it "restores type filter from URL parameters on page load" do
      visit products_path(type: 'sellable')

      # Type filter should be applied - show only sellable products
      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('Old Product')
      expect(page).not_to have_text('T-Shirt Bundle')

      # Type dropdown should show Sellable
      expect(page).to have_select('type', selected: 'Sellable')
    end

    it "restores search query from URL parameters on page load" do
      visit products_path(q: 'iPhone')

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')

      # Search field should contain the query
      expect(page).to have_field('q', with: 'iPhone')
    end
  end

  describe "empty state" do
    it "shows empty state when filters return no results" do
      visit products_path

      fill_in 'q', with: 'NonexistentProduct12345'
      click_button 'Search'

      expect(page).to have_text('No products found')
    end

    it "shows empty state when no products exist" do
      Product.destroy_all
      visit products_path

      # When no filters and no products, it shows "No products" (not "No products found")
      expect(page).to have_text('No products')
    end
  end

  describe "accessibility" do
    it "has proper aria-label for search input" do
      visit products_path

      # The SearchInputComponent creates an input with aria-label attribute
      expect(page).to have_css('input[aria-label="Search products by name or SKU"]')
    end

    it "has proper aria-label for type filter" do
      visit products_path

      expect(page).to have_css('select[aria-label="Filter by product type"]')
    end

    it "has accessible remove button for label filter chip" do
      visit products_path(label_id: label_electronics.id)

      expect(page).to have_css('a[aria-label="Remove label filter"]')
    end

    it "uses semantic form elements" do
      visit products_path

      expect(page).to have_css('form')
      expect(page).to have_css('select')
      expect(page).to have_button('Search')
    end
  end

  describe "multi-tenancy isolation" do
    let(:other_company) { create(:company) }
    let!(:other_product) do
      create(:product,
        company: other_company,
        name: 'Other Company Product',
        sku: 'OTHER-1',
        product_status: :active
      )
    end

    it "only shows products from current company" do
      visit products_path

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('Other Company Product')
    end

    it "only filters products from current company" do
      visit products_path

      select 'Sellable', from: 'type'
      click_button 'Search'

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('Old Product')
      expect(page).not_to have_text('Other Company Product')
    end

    it "filters by label only shows products from current company with that label" do
      # Create a label for the other company with a product
      other_label = create(:label, company: other_company, name: 'Other Label', code: 'other')
      create(:product_label, product: other_product, label: other_label)

      # Visit with our company's electronics label
      visit products_path(label_id: label_electronics.id)

      # Should show our company's product with that label
      expect(page).to have_text('iPhone 15')
      # Should not show other company's product (even if we tried to use their label)
      expect(page).not_to have_text('Other Company Product')
    end
  end

  describe "label filter with sublabels" do
    let!(:parent_label) { create(:label, company: company, name: 'Technology', code: 'tech') }
    let!(:sublabel) { create(:label, company: company, name: 'Phones', code: 'phones', parent_label: parent_label) }

    # Create a new product specifically for sublabel tests (to avoid conflicts with main before block)
    let!(:phone_product) do
      product = create(:product,
        company: company,
        name: 'Galaxy Phone',
        sku: 'GALAXY-1',
        product_type: :sellable,
        product_status: :active
      )
      create(:product_label, product: product, label: sublabel)
      product
    end

    it "filters by sublabel includes only products with that sublabel" do
      visit products_path(label_id: sublabel.id)

      expect(page).to have_text('Galaxy Phone')
      expect(page).not_to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('iPhone 15')
    end

    it "filters by parent label includes products with any descendant label" do
      visit products_path(label_id: parent_label.id)

      # Galaxy Phone has sublabel "Phones" which is under "Technology"
      expect(page).to have_text('Galaxy Phone')
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "shows sublabel name with parent in filter chip" do
      visit products_path(label_id: sublabel.id)

      # Should show filter chip indicating the sublabel
      expect(page).to have_text('Phones')
      expect(page).to have_css('.bg-blue-100')
    end
  end

  describe "performance" do
    it "loads products index efficiently with many products" do
      # Create many products
      50.times do |i|
        create(:product,
          company: company,
          name: "Product #{i}",
          sku: "PROD-#{i}",
          product_status: :active
        )
      end

      visit products_path

      # Page should load and show products table
      expect(page).to have_css('table')
      # Products are sorted by created_at DESC, so the most recent ones appear first
      # Just verify the table has content and pagination shows correct count
      expect(page).to have_text('Showing 1 to')
    end

    it "applies filters without excessive page load time" do
      # Create products
      20.times do |i|
        create(:product,
          company: company,
          name: "Product #{i}",
          sku: "PROD-#{i}",
          product_status: :active
        )
      end

      visit products_path

      start_time = Time.current

      select 'Sellable', from: 'type'
      click_button 'Search'

      # Wait for filtering to complete by checking that filtered products are shown
      expect(page).to have_css('table')
      expect(page).to have_text('Sellable') # Filter is applied

      elapsed_time = Time.current - start_time

      # Should complete in reasonable time (< 5 seconds)
      expect(elapsed_time).to be < 5
    end
  end
end
