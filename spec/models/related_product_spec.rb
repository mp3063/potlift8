require 'rails_helper'

RSpec.describe RelatedProduct, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:related_product)).to be_valid
    end

    it 'creates valid related products with all relation types' do
      expect(create(:related_product, :cross_sell)).to be_valid
      expect(create(:related_product, :upsell)).to be_valid
      expect(create(:related_product, :alternative)).to be_valid
      expect(create(:related_product, :accessory)).to be_valid
      expect(create(:related_product, :similar)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:related_to).class_name('Product') }
  end

  # Test validations
  describe 'validations' do
    subject { build(:related_product) }

    it { is_expected.to validate_presence_of(:relation_type) }

    it 'defines valid relation_type enum values' do
      expect(RelatedProduct.relation_types.keys).to contain_exactly(
        'cross_sell', 'upsell', 'alternative', 'accessory', 'similar'
      )
    end

    context 'related_to_id uniqueness' do
      let(:company) { create(:company) }
      let(:product) { create(:product, company: company) }
      let(:related_product) { create(:product, company: company) }

      before do
        create(:related_product, product: product, related_to: related_product, relation_type: 'cross_sell')
      end

      it 'validates uniqueness scoped to product and relation_type' do
        duplicate = build(:related_product, product: product, related_to: related_product, relation_type: 'cross_sell')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:related_to_id]).to include('has already been taken')
      end

      it 'allows same product relation with different type' do
        rp = build(:related_product, product: product, related_to: related_product, relation_type: 'upsell')
        expect(rp).to be_valid
      end

      it 'allows same related product for different main products' do
        other_product = create(:product, company: company)
        rp = build(:related_product, product: other_product, related_to: related_product, relation_type: 'cross_sell')
        expect(rp).to be_valid
      end
    end
  end

  # Test acts_as_list
  describe 'acts_as_list' do
    let(:product) { create(:product) }

    context 'scoped to product and relation_type' do
      it 'sets position within same type' do
        rp1 = create(:related_product, product: product, relation_type: 'cross_sell')
        rp2 = create(:related_product, product: product, relation_type: 'cross_sell')
        rp3 = create(:related_product, product: product, relation_type: 'cross_sell')

        expect(rp1.position).to eq(1)
        expect(rp2.position).to eq(2)
        expect(rp3.position).to eq(3)
      end

      it 'positions are independent across relation types' do
        cross_sell1 = create(:related_product, product: product, relation_type: 'cross_sell')
        upsell1 = create(:related_product, product: product, relation_type: 'upsell')

        expect(cross_sell1.position).to eq(1)
        expect(upsell1.position).to eq(1) # Independent position counter
      end

      it 'can reorder within same type' do
        rp1 = create(:related_product, product: product, relation_type: 'cross_sell')
        rp2 = create(:related_product, product: product, relation_type: 'cross_sell')
        rp3 = create(:related_product, product: product, relation_type: 'cross_sell')

        rp3.move_to_top
        rp1.reload
        rp2.reload
        rp3.reload

        expect(rp3.position).to eq(1)
        expect(rp1.position).to eq(2)
        expect(rp2.position).to eq(3)
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:product) { create(:product) }
    let!(:cross_sell1) { create(:related_product, :cross_sell, product: product) }
    let!(:cross_sell2) { create(:related_product, :cross_sell, product: product) }
    let!(:upsell1) { create(:related_product, :upsell, product: product) }
    let!(:alternative1) { create(:related_product, :alternative, product: product) }
    let!(:accessory1) { create(:related_product, :accessory, product: product) }
    let!(:similar1) { create(:related_product, :similar, product: product) }

    describe '.cross_sell' do
      it 'returns only cross_sell relations' do
        expect(RelatedProduct.cross_sell).to contain_exactly(cross_sell1, cross_sell2)
      end
    end

    describe '.upsell' do
      it 'returns only upsell relations' do
        expect(RelatedProduct.upsell).to contain_exactly(upsell1)
      end
    end

    describe '.alternative' do
      it 'returns only alternative relations' do
        expect(RelatedProduct.alternative).to contain_exactly(alternative1)
      end
    end

    describe '.accessory' do
      it 'returns only accessory relations' do
        expect(RelatedProduct.accessory).to contain_exactly(accessory1)
      end
    end

    describe '.similar' do
      it 'returns only similar relations' do
        expect(RelatedProduct.similar).to contain_exactly(similar1)
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:main_product) { create(:product, company: company, name: 'Main Product') }

    context 'product with multiple relation types' do
      let(:cross_sell_product) { create(:product, company: company, name: 'Cross-Sell Item') }
      let(:upsell_product) { create(:product, company: company, name: 'Premium Version') }
      let(:alternative_product) { create(:product, company: company, name: 'Alternative Product') }
      let(:accessory_product) { create(:product, company: company, name: 'Accessory') }
      let(:similar_product) { create(:product, company: company, name: 'Similar Product') }

      before do
        create(:related_product, product: main_product, related_to: cross_sell_product, relation_type: 'cross_sell')
        create(:related_product, product: main_product, related_to: upsell_product, relation_type: 'upsell')
        create(:related_product, product: main_product, related_to: alternative_product, relation_type: 'alternative')
        create(:related_product, product: main_product, related_to: accessory_product, relation_type: 'accessory')
        create(:related_product, product: main_product, related_to: similar_product, relation_type: 'similar')
      end

      it 'product has all relation types' do
        expect(main_product.related_products.count).to eq(5)
      end

      it 'can filter by relation type' do
        expect(main_product.related_products.cross_sell.count).to eq(1)
        expect(main_product.related_products.upsell.count).to eq(1)
        expect(main_product.related_products.alternative.count).to eq(1)
        expect(main_product.related_products.accessory.count).to eq(1)
        expect(main_product.related_products.similar.count).to eq(1)
      end

      it 'can access related product objects' do
        cross_sell_relations = main_product.related_products.cross_sell
        expect(cross_sell_relations.first.related_to).to eq(cross_sell_product)
      end
    end

    context 'multiple products of same relation type' do
      let!(:related1) { create(:product, company: company, name: 'Related 1') }
      let!(:related2) { create(:product, company: company, name: 'Related 2') }
      let!(:related3) { create(:product, company: company, name: 'Related 3') }

      before do
        create(:related_product, product: main_product, related_to: related1, relation_type: 'cross_sell')
        create(:related_product, product: main_product, related_to: related2, relation_type: 'cross_sell')
        create(:related_product, product: main_product, related_to: related3, relation_type: 'cross_sell')
      end

      it 'maintains order within relation type' do
        cross_sells = main_product.related_products.cross_sell.order(:position)
        expect(cross_sells.count).to eq(3)
        expect(cross_sells.pluck(:position)).to eq([ 1, 2, 3 ])
      end

      it 'can reorder within same type' do
        rp1 = main_product.related_products.cross_sell.order(:position).first
        rp3 = main_product.related_products.cross_sell.order(:position).last

        rp3.move_to_top

        cross_sells = main_product.related_products.cross_sell.order(:position)
        expect(cross_sells.first.related_to).to eq(related3)
      end
    end

    context 'bidirectional relationships' do
      let(:product_a) { create(:product, company: company, name: 'Product A') }
      let(:product_b) { create(:product, company: company, name: 'Product B') }

      it 'allows bidirectional similar relations' do
        create(:related_product, product: product_a, related_to: product_b, relation_type: 'similar')
        create(:related_product, product: product_b, related_to: product_a, relation_type: 'similar')

        expect(product_a.related_products.similar.first.related_to).to eq(product_b)
        expect(product_b.related_products.similar.first.related_to).to eq(product_a)
      end

      it 'allows asymmetric relations (A accessory of B, B does not relate to A)' do
        create(:related_product, product: main_product, related_to: product_a, relation_type: 'accessory')

        expect(main_product.related_products.accessory.count).to eq(1)
        expect(product_a.related_products.count).to eq(0)
      end
    end

    context 'related product deletion' do
      let(:related) { create(:product, company: company) }
      let!(:relation) { create(:related_product, product: main_product, related_to: related, relation_type: 'cross_sell') }

      it 'removes relation when related product is destroyed' do
        expect {
          related.destroy
        }.to change { RelatedProduct.count }.by(-1)
      end

      it 'removes all relations when main product is destroyed' do
        expect {
          main_product.destroy
        }.to change { RelatedProduct.count }.by(-1)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    it 'product cannot be related to itself' do
      rp = build(:related_product, product: product, related_to: product, relation_type: 'similar')
      expect(rp).not_to be_valid
    end

    it 'same product can be related multiple times with different types' do
      related = create(:product, company: company)

      create(:related_product, product: product, related_to: related, relation_type: 'cross_sell')
      create(:related_product, product: product, related_to: related, relation_type: 'similar')

      expect(product.related_products.count).to eq(2)
    end

    it 'raises ArgumentError for invalid relation_type' do
      expect {
        build(:related_product, relation_type: 'invalid_type')
      }.to raise_error(ArgumentError, /'invalid_type' is not a valid relation_type/)
    end

    it 'allows large number of related products' do
      20.times do |_i|
        related = create(:product, company: company)
        create(:related_product, product: product, related_to: related, relation_type: 'cross_sell')
      end

      expect(product.related_products.cross_sell.count).to eq(20)
    end
  end

  # Multi-tenancy
  describe 'multi-tenancy' do
    let(:company) { create(:company) }
    let(:other_company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:related_product) { create(:product, company: company) }
    let(:other_related_product) { create(:product, company: other_company) }

    it 'related product must be from same company' do
      expect {
        create(:related_product, product: product, related_to: other_related_product, relation_type: 'cross_sell')
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it 'relation is valid when products are from same company' do
      rp = build(:related_product, product: product, related_to: related_product, relation_type: 'cross_sell')
      expect(rp).to be_valid
    end
  end
end
