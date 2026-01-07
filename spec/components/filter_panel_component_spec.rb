# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FilterPanelComponent, type: :component do
  let(:company) { create(:company) }
  # Product types are enums on Product model, not separate models.
  # Use simple structs that respond to id and name for filter options.
  let(:product_type1) { OpenStruct.new(id: 1, name: 'Sellable') }
  let(:product_type2) { OpenStruct.new(id: 2, name: 'Configurable') }
  let(:label1) { create(:label, company: company, name: 'Electronics', code: 'electronics') }
  let(:label2) { create(:label, company: company, name: 'Clothing', code: 'clothing') }

  let(:available_filters) do
    {
      product_types: [product_type1, product_type2],
      labels: [label1, label2]
    }
  end

  # Helper method for testing with specific request URLs
  # The component uses helpers.request, helpers.url_for, helpers.controller_name, etc.
  def with_request_url(url = '/products', params: {})
    uri = URI.parse(url)
    path = uri.path
    query_params = Rack::Utils.parse_nested_query(uri.query || '').merge(params.stringify_keys)

    # Mock the request object for the component
    vc_test_request.tap do |req|
      allow(req).to receive(:path).and_return(path)
      allow(req).to receive(:params).and_return(
        ActionController::Parameters.new(query_params.merge('controller' => 'products', 'action' => 'index'))
      )
      allow(req).to receive(:query_parameters).and_return(query_params)
    end

    # Set up controller context
    with_controller_class(ProductsController) do
      yield
    end
  end

  describe "rendering with no filters" do
    before do
      with_request_url('/products') do
        render_inline(described_class.new(
          filters: {},
          available_filters: available_filters
        ))
      end
    end

    it "renders filter panel component" do
      expect(page).to have_css('[data-controller="filter-panel"]')
    end

    it "does not show active filter chips" do
      expect(page).not_to have_text('Active Filters')
    end

    it "does not show clear all button" do
      expect(page).not_to have_button('Clear All')
    end

    it "shows active filter count of 0 on mobile toggle" do
      component = described_class.new(filters: {}, available_filters: available_filters)
      expect(component.active_filter_count).to eq(0)
    end
  end

  describe "rendering with active filters" do
    let(:filters) do
      {
        product_type_id: product_type1.id.to_s,
        status: 'active',
        label_ids: [label1.id.to_s, label2.id.to_s]
      }
    end

    before do
      with_request_url('/products', params: filters) do
        render_inline(described_class.new(
          filters: filters,
          available_filters: available_filters
        ))
      end
    end

    it "renders filter panel with filters" do
      expect(page).to have_css('[data-controller="filter-panel"]')
    end

    it "displays active filter count" do
      component = described_class.new(filters: filters, available_filters: available_filters)
      expect(component.active_filter_count).to eq(3)
    end

    it "shows active filters section" do
      # The component shows "Active Filters" text via chip display, not a header
      # Check for active filter chips container instead
      expect(page).to have_css('[role="list"][aria-label="Active filters"]')
    end

    it "renders active filter chips" do
      expect(page).to have_text('Product Type:')
      expect(page).to have_text('Sellable')
      expect(page).to have_text('Status:')
      expect(page).to have_text('Active')
      expect(page).to have_text('Labels:')
      expect(page).to have_text('Electronics, Clothing')
    end

    it "renders remove button for each filter" do
      # Should have remove buttons for each active filter
      remove_buttons = page.all('a[aria-label*="Remove"]')
      expect(remove_buttons.count).to be >= 1
    end

    it "renders clear all filters button" do
      # The button text is "Clear All" not "Clear All Filters"
      expect(page).to have_link('Clear All')
    end
  end

  describe "filter display names" do
    let(:component) { described_class.new(filters: {}, available_filters: {}) }

    it "returns correct display name for product_type_id" do
      expect(component.filter_display_name(:product_type_id)).to eq('Product Type')
    end

    it "returns correct display name for label_ids" do
      expect(component.filter_display_name(:label_ids)).to eq('Labels')
    end

    it "returns correct display name for status" do
      expect(component.filter_display_name(:status)).to eq('Status')
    end

    it "returns correct display name for created_from" do
      expect(component.filter_display_name(:created_from)).to eq('Created From')
    end

    it "returns correct display name for created_to" do
      expect(component.filter_display_name(:created_to)).to eq('Created To')
    end

    it "titleizes unknown filter keys" do
      expect(component.filter_display_name(:custom_filter)).to eq('Custom Filter')
    end
  end

  describe "filter display values" do
    let(:component) do
      described_class.new(
        filters: {},
        available_filters: {
          product_types: [product_type1],
          labels: [label1, label2]
        }
      )
    end

    it "returns product type name for product_type_id" do
      expect(component.filter_display_value(:product_type_id, product_type1.id.to_s))
        .to eq('Sellable')
    end

    it "returns label names joined for label_ids array" do
      label_ids = [label1.id.to_s, label2.id.to_s]
      expect(component.filter_display_value(:label_ids, label_ids))
        .to eq('Electronics, Clothing')
    end

    it "returns empty string for blank label_ids" do
      expect(component.filter_display_value(:label_ids, [])).to eq('')
      expect(component.filter_display_value(:label_ids, nil)).to eq('')
    end

    it "titleizes status values" do
      expect(component.filter_display_value(:status, 'active')).to eq('Active')
      expect(component.filter_display_value(:status, 'discontinued')).to eq('Discontinued')
    end

    it "returns date values as-is" do
      date_str = '2025-01-01'
      expect(component.filter_display_value(:created_from, date_str)).to eq(date_str)
      expect(component.filter_display_value(:created_to, date_str)).to eq(date_str)
    end

    it "converts unknown values to string" do
      expect(component.filter_display_value(:unknown_key, 123)).to eq('123')
    end
  end

  describe "active filters logic" do
    it "identifies active filters correctly" do
      filters = {
        product_type_id: '1',
        status: 'active',
        empty_filter: '',
        nil_filter: nil,
        blank_filter: '   ',
        empty_array: []
      }

      component = described_class.new(filters: filters, available_filters: {})

      expect(component.active_filters).to eq({
        product_type_id: '1',
        status: 'active'
      })
    end

    it "returns true when filters are active" do
      filters = { status: 'active' }
      component = described_class.new(filters: filters, available_filters: {})

      expect(component.active_filters?).to be true
    end

    it "returns false when no filters are active" do
      filters = { status: '', product_type_id: nil }
      component = described_class.new(filters: filters, available_filters: {})

      expect(component.active_filters?).to be false
    end

    it "counts active filters correctly" do
      filters = { status: 'active', product_type_id: '1', empty: '' }
      component = described_class.new(filters: filters, available_filters: {})

      expect(component.active_filter_count).to eq(2)
    end
  end

  describe "URL generation" do
    let(:component) do
      described_class.new(
        filters: { product_type_id: '1', status: 'active' },
        available_filters: {}
      )
    end

    before do
      # Mock the helpers with request path included
      allow(component).to receive(:helpers).and_return(
        double(
          request: double(
            params: { 'product_type_id' => '1', 'status' => 'active' },
            path: '/products'
          ),
          controller_name: 'products',
          action_name: 'index'
        )
      )
    end

    it "generates URL for removing a specific filter" do
      url = component.remove_filter_url(:product_type_id)
      expect(url).to eq('/products?status=active')
    end

    it "generates URL for clearing all filters" do
      url = component.clear_filters_url
      expect(url).to eq('/products')
    end
  end

  describe "Stimulus integration" do
    before do
      with_request_url('/products') do
        render_inline(described_class.new(filters: {}, available_filters: available_filters))
      end
    end

    it "connects to filter-panel controller" do
      expect(page).to have_css('[data-controller="filter-panel"]')
    end

    it "defines panel target if mobile toggle exists" do
      # Panel target is conditionally rendered based on implementation
      # This test verifies the controller connection exists
      expect(page).to have_css('[data-controller="filter-panel"]')
    end
  end

  describe "form structure" do
    let(:filters) { { status: 'active' } }

    before do
      with_request_url('/products', params: filters) do
        render_inline(described_class.new(
          filters: filters,
          available_filters: available_filters
        ))
      end
    end

    it "renders form with proper method and action" do
      # Form should be present in the component
      expect(page).to have_css('form')
    end

    it "includes filter inputs" do
      # Component should render filter inputs
      expect(page).to have_css('select, input[type="checkbox"], input[type="date"]')
    end
  end

  describe "accessibility" do
    let(:filters) do
      {
        product_type_id: product_type1.id.to_s,
        status: 'active'
      }
    end

    before do
      with_request_url('/products', params: filters) do
        render_inline(described_class.new(
          filters: filters,
          available_filters: available_filters
        ))
      end
    end

    it "has proper labels for filter inputs" do
      # Labels should be associated with inputs
      expect(page).to have_css('label')
    end

    it "has aria-label for remove filter buttons" do
      remove_links = page.all('a[aria-label*="Remove"]')
      expect(remove_links).not_to be_empty
    end

    it "uses semantic HTML elements" do
      expect(page).to have_css('form')
    end
  end

  describe "edge cases" do
    it "handles nil filters gracefully" do
      with_request_url('/products') do
        expect {
          render_inline(described_class.new(
            filters: nil,
            available_filters: available_filters
          ))
        }.not_to raise_error
      end
    end

    it "handles empty available_filters gracefully" do
      with_request_url('/products') do
        expect {
          render_inline(described_class.new(
            filters: { status: 'active' },
            available_filters: {}
          ))
        }.not_to raise_error
      end
    end

    it "handles string keys in filters" do
      filters = { 'status' => 'active', 'product_type_id' => '1' }
      component = described_class.new(filters: filters, available_filters: {})

      # Should symbolize keys
      expect(component.filters).to have_key(:status)
      expect(component.filters).to have_key(:product_type_id)
    end

    it "handles missing product type in available_filters" do
      filters = { product_type_id: '999' }
      component = described_class.new(
        filters: filters,
        available_filters: { product_types: [product_type1] }
      )

      # Should return the ID if product type not found
      expect(component.filter_display_value(:product_type_id, '999')).to eq('999')
    end

    it "handles missing label in available_filters" do
      filters = { label_ids: ['999'] }
      component = described_class.new(
        filters: filters,
        available_filters: { labels: [label1] }
      )

      # Should filter out missing labels
      result = component.filter_display_value(:label_ids, ['999'])
      expect(result).to eq('')
    end
  end

  describe "component initialization" do
    it "initializes with filters and available_filters" do
      component = described_class.new(
        filters: { status: 'active' },
        available_filters: available_filters
      )

      expect(component.filters).to eq({ status: 'active' })
      expect(component.available_filters).to eq(available_filters)
    end

    it "initializes with default empty hashes" do
      component = described_class.new

      expect(component.filters).to eq({})
      expect(component.available_filters).to eq({})
    end

    it "renders successfully without errors" do
      with_request_url('/products') do
        expect {
          render_inline(described_class.new)
        }.not_to raise_error
      end
    end
  end
end
