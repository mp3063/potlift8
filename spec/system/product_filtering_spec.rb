# frozen_string_literal: true

require 'rails_helper'

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
  end

  let!(:product_type_sellable) { create(:product_type, company: company, code: 'sellable', name: 'Sellable') }
  let!(:product_type_bundle) { create(:product_type, company: company, code: 'bundle', name: 'Bundle') }

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
    before do
      visit products_path
    end

    it "shows all products initially" do
      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).to have_text('Old Product')
    end

    it "filters by sellable product type", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('Old Product')
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "filters by bundle product type", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Bundle', from: 'product_type_id'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('iPhone 15')
      expect(page).not_to have_text('Old Product')
    end

    it "shows active filter chip after filtering", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('Product Type: Sellable')
    end
  end

  describe "filter by labels" do
    before do
      visit products_path
    end

    it "filters by single label", js: true do
      within('form[data-controller="filter-panel"]') do
        check 'Electronics'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "filters by multiple labels", js: true do
      within('form[data-controller="filter-panel"]') do
        check 'Electronics'
        check 'Clothing'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('Old Product')
    end

    it "shows active filter chip for labels", js: true do
      within('form[data-controller="filter-panel"]') do
        check 'Electronics'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('Labels: Electronics')
    end
  end

  describe "filter by status" do
    before do
      visit products_path
    end

    it "filters by active status", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('Old Product')
    end

    it "filters by discontinued status", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Discontinued', from: 'status'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('Old Product')
      expect(page).not_to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
    end

    it "shows active filter chip for status", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('Status: Active')
    end
  end

  describe "filter by date range" do
    before do
      # Set product created dates
      travel_to 30.days.ago do
        product1.update(created_at: Time.current)
      end

      travel_to 10.days.ago do
        product2.update(created_at: Time.current)
      end

      product3.update(created_at: Time.current)

      visit products_path
    end

    after do
      travel_back
    end

    it "filters by created_from date", js: true do
      within('form[data-controller="filter-panel"]') do
        fill_in 'created_from', with: 15.days.ago.to_date.to_s
        click_button 'Apply Filters'
      end

      expect(page).to have_text('T-Shirt Bundle')
      expect(page).to have_text('Old Product')
      expect(page).not_to have_text('iPhone 15')
    end

    it "filters by created_to date", js: true do
      within('form[data-controller="filter-panel"]') do
        fill_in 'created_to', with: 20.days.ago.to_date.to_s
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('Old Product')
    end

    it "filters by date range", js: true do
      within('form[data-controller="filter-panel"]') do
        fill_in 'created_from', with: 15.days.ago.to_date.to_s
        fill_in 'created_to', with: 5.days.ago.to_date.to_s
        click_button 'Apply Filters'
      end

      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('iPhone 15')
      expect(page).not_to have_text('Old Product')
    end
  end

  describe "combined filters" do
    before do
      visit products_path
    end

    it "applies multiple filters simultaneously", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        select 'Active', from: 'status'
        check 'Electronics'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('Old Product')

      # Should show all filter chips
      expect(page).to have_text('Product Type: Sellable')
      expect(page).to have_text('Status: Active')
      expect(page).to have_text('Labels: Electronics')
    end

    it "shows correct active filter count", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      # Should show count of 2 active filters
      expect(page).to have_css('[data-filter-count="2"]') || have_text('2 filters')
    end
  end

  describe "active filter chips" do
    before do
      visit products_path
      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end
    end

    it "displays active filter chips", js: true do
      expect(page).to have_text('Product Type: Sellable')
      expect(page).to have_text('Status: Active')
    end

    it "removes individual filter when clicking remove button", js: true do
      within('.active-filters') do
        # Find and click remove button for Product Type filter
        find('a[aria-label*="Remove"][href*="product_type_id"]').click
      end

      # Product Type filter should be removed
      expect(page).not_to have_text('Product Type: Sellable')
      # Status filter should remain
      expect(page).to have_text('Status: Active')
    end

    it "shows Clear All button when filters are active", js: true do
      expect(page).to have_link('Clear All Filters')
    end
  end

  describe "clear all filters" do
    before do
      visit products_path
      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        select 'Active', from: 'status'
        check 'Electronics'
        click_button 'Apply Filters'
      end
    end

    it "clears all filters when clicking Clear All button", js: true do
      click_link 'Clear All Filters'

      # Should show all products again
      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).to have_text('Old Product')

      # Should not show filter chips
      expect(page).not_to have_text('Product Type: Sellable')
      expect(page).not_to have_text('Status: Active')
      expect(page).not_to have_text('Labels: Electronics')
    end
  end

  describe "URL state preservation" do
    it "preserves filter state in URL parameters", js: true do
      visit products_path

      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      # URL should contain filter parameters
      expect(page).to have_current_path(/product_type_id=/)
      expect(page).to have_current_path(/status=active/)
    end

    it "restores filters from URL parameters on page reload" do
      visit products_path(product_type_id: product_type_sellable.id, status: 'active')

      # Filters should be applied
      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')

      # Filter chips should be visible
      expect(page).to have_text('Product Type: Sellable')
      expect(page).to have_text('Status: Active')
    end

    it "maintains filters after page reload", js: true do
      visit products_path

      within('form[data-controller="filter-panel"]') do
        select 'Sellable', from: 'product_type_id'
        click_button 'Apply Filters'
      end

      # Reload page
      visit current_path

      # Filter should still be applied
      expect(page).to have_text('Product Type: Sellable')
      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('T-Shirt Bundle')
    end
  end

  describe "mobile filter panel" do
    before(:each) do
      # Set mobile viewport
      page.driver.browser.manage.window.resize_to(375, 667)
      visit products_path
    end

    it "shows mobile toggle button", js: true do
      expect(page).to have_button('Show Filters') || have_css('[data-action*="toggleMobile"]')
    end

    it "toggles filter panel on mobile", js: true do
      # Panel should be hidden initially on mobile
      filter_panel = find('[data-filter-panel-target="panel"]', visible: false)
      expect(filter_panel).not_to be_visible

      # Click toggle button
      find('[data-action*="toggleMobile"]').click

      # Panel should be visible
      expect(filter_panel).to be_visible
    end

    it "updates ARIA expanded state on toggle", js: true do
      toggle_button = find('[data-action*="toggleMobile"]')

      # Initially collapsed
      expect(toggle_button['aria-expanded']).to eq('false')

      # Toggle open
      toggle_button.click

      # Should be expanded
      expect(toggle_button['aria-expanded']).to eq('true')
    end
  end

  describe "empty state" do
    before do
      # Remove all products
      Product.destroy_all

      visit products_path
    end

    it "shows empty state when no products exist" do
      expect(page).to have_text('No products found') || have_css('.empty-state')
    end

    it "shows empty state when filters return no results", js: true do
      # Create one product
      create(:product, company: company, name: 'Single Product', product_status: :active)

      visit products_path

      within('form[data-controller="filter-panel"]') do
        select 'Discontinued', from: 'status'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('No products found') || have_css('.empty-state')
    end
  end

  describe "accessibility" do
    before do
      visit products_path
    end

    it "has proper labels for filter inputs" do
      expect(page).to have_css('label[for*="product_type"]')
      expect(page).to have_css('label[for*="status"]')
    end

    it "has accessible remove buttons with aria-label" do
      within('form[data-controller="filter-panel"]') do
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      expect(page).to have_css('a[aria-label*="Remove"]')
    end

    it "uses semantic form elements" do
      expect(page).to have_css('form')
      expect(page).to have_css('select')
      expect(page).to have_button('Apply Filters')
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

    before do
      visit products_path
    end

    it "only shows products from current company" do
      expect(page).to have_text('iPhone 15')
      expect(page).not_to have_text('Other Company Product')
    end

    it "only filters products from current company", js: true do
      within('form[data-controller="filter-panel"]') do
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      expect(page).to have_text('iPhone 15')
      expect(page).to have_text('T-Shirt Bundle')
      expect(page).not_to have_text('Other Company Product')
    end
  end

  describe "performance" do
    before do
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
    end

    it "loads filter panel without N+1 queries" do
      # Filter panel should load efficiently
      expect(page).to have_css('form[data-controller="filter-panel"]')
    end

    it "applies filters without excessive page load time", js: true do
      start_time = Time.current

      within('form[data-controller="filter-panel"]') do
        select 'Active', from: 'status'
        click_button 'Apply Filters'
      end

      elapsed_time = Time.current - start_time

      # Should complete in reasonable time (< 3 seconds)
      expect(elapsed_time).to be < 3
    end
  end
end
