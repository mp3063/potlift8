# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductsController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { { id: 1, email: 'test@example.com', name: 'Test User' } }

  before do
    # Simulate authentication
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:current_company).and_return(
      { id: company.id, code: company.code, name: company.name }
    )
    allow(controller).to receive(:current_potlift_company).and_return(company)
    allow(controller).to receive(:authenticated?).and_return(true)
  end

  describe '#calculate_label_product_counts' do
    before do
      # Create hierarchical label structure
      # Root 1
      #   - Child 1.1
      #     - Grandchild 1.1.1
      #   - Child 1.2
      # Root 2
      #   - Child 2.1

      @root1 = create(:label, company: company, code: 'root1', name: 'Root 1')
      @child1_1 = create(:label, company: company, code: 'child1-1', name: 'Child 1.1', parent_label: @root1)
      @grandchild1_1_1 = create(:label, company: company, code: 'grandchild1-1-1', name: 'Grandchild 1.1.1', parent_label: @child1_1)
      @child1_2 = create(:label, company: company, code: 'child1-2', name: 'Child 1.2', parent_label: @root1)

      @root2 = create(:label, company: company, code: 'root2', name: 'Root 2')
      @child2_1 = create(:label, company: company, code: 'child2-1', name: 'Child 2.1', parent_label: @root2)

      # Create products with different label associations
      @product1 = create(:product, company: company, sku: 'PROD1')
      @product1.labels << @grandchild1_1_1  # Tagged with grandchild

      @product2 = create(:product, company: company, sku: 'PROD2')
      @product2.labels << @child1_1  # Tagged with child

      @product3 = create(:product, company: company, sku: 'PROD3')
      @product3.labels << @child1_2  # Tagged with different child

      @product4 = create(:product, company: company, sku: 'PROD4')
      @product4.labels << @child2_1  # Tagged with root2's child

      @product5 = create(:product, company: company, sku: 'PROD5')
      @product5.labels << [ @child1_1, @child1_2 ]  # Tagged with multiple labels
    end

    it 'calculates correct product counts including descendants' do
      label_counts = controller.send(:calculate_label_product_counts)

      # Root 1 should count products tagged with:
      # - child1_1 (PROD2, PROD5)
      # - grandchild1_1_1 (PROD1)
      # - child1_2 (PROD3, PROD5)
      # Total unique products: PROD1, PROD2, PROD3, PROD5 = 4
      expect(label_counts[@root1.id]).to eq(4)

      # Child 1.1 should count products tagged with:
      # - child1_1 (PROD2, PROD5)
      # - grandchild1_1_1 (PROD1)
      # Total unique products: PROD1, PROD2, PROD5 = 3
      expect(label_counts[@child1_1.id]).to eq(3)

      # Grandchild 1.1.1 (leaf) should only count direct associations
      expect(label_counts[@grandchild1_1_1.id]).to eq(1)

      # Child 1.2 (leaf) should only count direct associations
      # PROD3, PROD5 = 2
      expect(label_counts[@child1_2.id]).to eq(2)

      # Root 2 should count products tagged with:
      # - child2_1 (PROD4)
      expect(label_counts[@root2.id]).to eq(1)

      # Child 2.1 (leaf) should only count direct associations
      expect(label_counts[@child2_1.id]).to eq(1)
    end

    it 'handles labels with no products' do
      # Create label with no products
      empty_label = create(:label, company: company, code: 'empty', name: 'Empty Label')

      label_counts = controller.send(:calculate_label_product_counts)

      expect(label_counts[empty_label.id]).to eq(0)
    end

    it 'handles products tagged with multiple labels in hierarchy correctly' do
      # PROD5 is tagged with both child1_1 and child1_2
      # It should only be counted once per parent label

      label_counts = controller.send(:calculate_label_product_counts)

      # Root 1 should count PROD5 only once even though it has 2 child labels
      expect(label_counts[@root1.id]).to eq(4)  # Not 5!
    end

    it 'executes minimal number of database queries' do
      # Reset query counter
      query_count = 0
      query_listener = ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
        data = args.last
        # Only count actual queries (not EXPLAIN or schema queries)
        query_count += 1 unless data[:sql] =~ /EXPLAIN|SCHEMA|SHOW/i
      end

      controller.send(:calculate_label_product_counts)

      ActiveSupport::Notifications.unsubscribe(query_listener)

      # Expected queries:
      # 1. Load all labels for company
      # 2. Load product_labels associations (product_id, label_id)
      # Total: 2 queries (vs 80+ in old implementation)
      puts "  Query count: #{query_count}"
      expect(query_count).to be <= 3  # Allow 1 extra for caching/transactions
    end
  end

  describe '#build_descendant_map' do
    it 'builds correct descendant mapping' do
      root = create(:label, company: company, code: 'root', name: 'Root')
      child1 = create(:label, company: company, code: 'child1', name: 'Child 1', parent_label: root)
      child2 = create(:label, company: company, code: 'child2', name: 'Child 2', parent_label: root)
      grandchild = create(:label, company: company, code: 'gc1', name: 'Grandchild 1', parent_label: child1)

      all_labels = [ root, child1, child2, grandchild ]
      descendant_map = controller.send(:build_descendant_map, all_labels)

      # Root should have all descendants
      expect(descendant_map[root.id]).to contain_exactly(child1.id, child2.id, grandchild.id)

      # Child1 should have only grandchild
      expect(descendant_map[child1.id]).to contain_exactly(grandchild.id)

      # Child2 should have no descendants
      expect(descendant_map[child2.id]).to be_empty

      # Grandchild should have no descendants
      expect(descendant_map[grandchild.id]).to be_empty
    end
  end

  describe '#collect_descendants' do
    it 'recursively collects all descendant IDs' do
      children_map = {
        1 => [ 2, 3 ],
        2 => [ 4 ],
        3 => [],
        4 => []
      }

      result = controller.send(:collect_descendants, 1, children_map)

      # Should collect: 2, 3 (direct children) + 4 (grandchild via 2)
      expect(result).to contain_exactly(2, 3, 4)
    end

    it 'returns empty array for leaf nodes' do
      children_map = {
        1 => [ 2 ],
        2 => []
      }

      result = controller.send(:collect_descendants, 2, children_map)

      expect(result).to be_empty
    end
  end
end
