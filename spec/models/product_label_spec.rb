require 'rails_helper'

RSpec.describe ProductLabel, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:product_label)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:label) }
  end

  # Test validations
  describe 'validations' do
    let(:product) { create(:product) }
    let(:label) { create(:label) }

    before do
      create(:product_label, product: product, label: label)
    end

    it 'validates uniqueness of product_id scoped to label_id' do
      duplicate = build(:product_label, product: product, label: label)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:product_id]).to include('has already been taken')
    end

    it 'allows same product with different labels' do
      other_label = create(:label)
      product_label = build(:product_label, product: product, label: other_label)
      expect(product_label).to be_valid
    end

    it 'allows same label with different products' do
      other_product = create(:product)
      product_label = build(:product_label, product: other_product, label: label)
      expect(product_label).to be_valid
    end
  end

  # Test callbacks
  describe 'callbacks' do
    let(:product) { create(:product) }
    let(:label) { create(:label) }
    let(:product_label) { create(:product_label, product: product, label: label) }

    describe 'after_save :touch_product' do
      it 'touches product when product_label is saved' do
        expect { product_label.update(updated_at: 1.day.ago) }
          .to change { product.reload.updated_at }
      end
    end

    describe 'after_destroy :touch_product' do
      it 'touches product when product_label is destroyed' do
        product_label # Create it first
        expect { product_label.destroy }
          .to change { product.reload.updated_at }
      end
    end

    describe 'after_touch :touch_product' do
      it 'touches product when product_label is touched' do
        expect { product_label.touch }
          .to change { product.reload.updated_at }
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    context 'multiple labels per product' do
      let(:category) { create(:label, company: company, label_type: 'category') }
      let(:tag) { create(:label, company: company, label_type: 'tag') }
      let(:brand) { create(:label, company: company, label_type: 'brand') }

      before do
        create(:product_label, product: product, label: category)
        create(:product_label, product: product, label: tag)
        create(:product_label, product: product, label: brand)
      end

      it 'allows product to have multiple labels' do
        expect(product.labels.count).to eq(3)
        expect(product.labels).to contain_exactly(category, tag, brand)
      end
    end

    context 'multiple products per label' do
      let(:label) { create(:label, company: company) }
      let(:product1) { create(:product, company: company) }
      let(:product2) { create(:product, company: company) }
      let(:product3) { create(:product, company: company) }

      before do
        create(:product_label, product: product1, label: label)
        create(:product_label, product: product2, label: label)
        create(:product_label, product: product3, label: label)
      end

      it 'allows label to have multiple products' do
        expect(label.products.count).to eq(3)
        expect(label.products).to contain_exactly(product1, product2, product3)
      end
    end

    context 'hierarchical labels' do
      let(:root) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
      let(:child) { create(:label, company: company, code: 'phones', name: 'Phones', parent_label: root) }

      it 'allows product to be tagged with hierarchical labels' do
        create(:product_label, product: product, label: root)
        create(:product_label, product: product, label: child)

        expect(product.labels).to contain_exactly(root, child)
      end
    end

    context 'cache invalidation' do
      let(:label) { create(:label, company: company) }
      let!(:product_label) { create(:product_label, product: product, label: label) }

      before do
        product.update_column(:updated_at, 1.hour.ago)
      end

      it 'invalidates product cache when label association changes' do
        original_updated_at = product.updated_at
        product_label.touch
        expect(product.reload.updated_at).to be > original_updated_at
      end
    end
  end
end
