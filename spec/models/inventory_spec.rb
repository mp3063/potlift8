require 'rails_helper'

RSpec.describe Inventory, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:inventory)).to be_valid
    end

    it 'creates valid inventory with traits' do
      expect(create(:inventory, :out_of_stock)).to be_valid
      expect(create(:inventory, :high_stock)).to be_valid
      expect(create(:inventory, :incoming_with_eta)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:storage) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:inventory) }

    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value).only_integer }

    context 'uniqueness validations' do
      let(:product) { create(:product) }
      let(:storage) { create(:storage) }

      before do
        create(:inventory, product: product, storage: storage)
      end

      it 'validates uniqueness of product_id scoped to storage_id' do
        duplicate = build(:inventory, product: product, storage: storage)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:product_id]).to include('has already been taken')
      end

      it 'allows same product in different storages' do
        other_storage = create(:storage)
        inventory = build(:inventory, product: product, storage: other_storage)
        expect(inventory).to be_valid
      end

      it 'allows different products in same storage' do
        other_product = create(:product)
        inventory = build(:inventory, product: other_product, storage: storage)
        expect(inventory).to be_valid
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:storage1) { create(:storage, company: company) }
    let(:storage2) { create(:storage, company: company) }

    describe '.for_product' do
      let!(:inventory1) { create(:inventory, product: product, storage: storage1) }
      let!(:inventory2) { create(:inventory, product: product, storage: storage2) }
      let!(:other_inventory) { create(:inventory) }

      it 'returns inventories for specified product' do
        result = Inventory.for_product(product)
        expect(result).to contain_exactly(inventory1, inventory2)
        expect(result).not_to include(other_inventory)
      end
    end

    describe '.except_in' do
      let!(:inventory1) { create(:inventory, product: product, storage: storage1) }
      let!(:inventory2) { create(:inventory, product: product, storage: storage2) }

      it 'returns inventories not in specified storage' do
        result = Inventory.except_in(storage1)
        expect(result).to include(inventory2)
        expect(result).not_to include(inventory1)
      end
    end

    describe '.with_stock' do
      let!(:in_stock) { create(:inventory, value: 10) }
      let!(:out_of_stock) { create(:inventory, value: 0) }
      let!(:high_stock) { create(:inventory, value: 1000) }

      it 'returns only inventories with value > 0' do
        result = Inventory.with_stock
        expect(result).to contain_exactly(in_stock, high_stock)
        expect(result).not_to include(out_of_stock)
      end
    end

    describe '.incoming' do
      let(:incoming_storage) { create(:storage, :incoming, company: company) }
      let(:regular_storage) { create(:storage, :regular, company: company) }
      let!(:incoming_inventory) { create(:inventory, storage: incoming_storage, product: product) }
      let!(:regular_inventory) { create(:inventory, storage: regular_storage, product: product) }

      it 'returns only inventories in incoming storage' do
        result = Inventory.incoming
        expect(result).to include(incoming_inventory)
        expect(result).not_to include(regular_inventory)
      end
    end
  end

  # Test instance methods
  describe 'instance methods' do
    describe '#as_json' do
      let(:company) { create(:company) }
      let(:storage) { create(:storage, company: company, code: 'WH01', name: 'Warehouse 1', default: true) }
      let(:product) { create(:product, company: company) }
      let(:inventory) { create(:inventory, product: product, storage: storage, value: 100) }

      context 'without catalog options' do
        it 'returns standard JSON' do
          json = inventory.as_json
          expect(json['storage_id']).to eq(storage.id)
          expect(json['value']).to eq(100)
        end
      end

      context 'with catalog options' do
        it 'includes storage attributes and excludes storage_id' do
          json = inventory.as_json(include_related_objects_for_catalog: true)

          expect(json['storage_id']).to be_nil
          expect(json['code']).to eq('WH01')
          expect(json['name']).to eq('Warehouse 1')
          expect(json['storage_type']).to eq('regular')
          expect(json['default']).to be true
        end

        it 'excludes sensitive storage fields' do
          json = inventory.as_json(include_related_objects_for_catalog: true)

          expect(json['id']).to be_present # inventory id is kept
          expect(json).not_to have_key('company_id')
          # Note: info comes from storage.as_json and is not excluded in the model
          # The model excludes [:id, :company_id, :info, :created_at, :updated_at, :default]
          # from storage, but inventory's own info may still be present
        end
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores custom metadata' do
        inventory = create(:inventory, :with_info)
        expect(inventory.info['batch_number']).to eq('BATCH-001')
        expect(inventory.info['notes']).to eq('Special handling required')
      end

      it 'defaults to empty hash' do
        inventory = create(:inventory)
        expect(inventory.info).to eq({})
      end
    end
  end

  # Test default values
  describe 'default values' do
    it 'defaults value to 0' do
      inventory = Inventory.new(product: create(:product), storage: create(:storage))
      expect(inventory.value).to eq(0)
    end

    it 'defaults default to false' do
      inventory = create(:inventory)
      expect(inventory.default).to be false
    end

    it 'defaults eta to nil' do
      inventory = create(:inventory)
      expect(inventory.eta).to be_nil
    end
  end

  # Test ETA field
  describe 'eta field' do
    it 'accepts date values' do
      # eta is a date column, not datetime
      eta = 7.days.from_now.to_date
      inventory = create(:inventory, eta: eta)
      expect(inventory.eta).to eq(eta)
    end

    it 'is commonly used with incoming storage' do
      inventory = create(:inventory, :incoming_with_eta)
      expect(inventory.storage.incoming?).to be true
      expect(inventory.eta).to be_present
    end
  end

  # Test value tracking
  describe 'value tracking' do
    let(:inventory) { create(:inventory, value: 10) }

    it 'allows updating inventory value' do
      inventory.update(value: 20)
      expect(inventory.reload.value).to eq(20)
    end

    it 'allows zero value' do
      inventory.update(value: 0)
      expect(inventory.reload.value).to eq(0)
    end

    it 'allows negative values for corrections' do
      inventory.update(value: -5)
      expect(inventory.reload.value).to eq(-5)
    end

    it 'rejects non-integer values' do
      inventory.value = 10.5
      expect(inventory).not_to be_valid
      expect(inventory.errors[:value]).to be_present
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:regular_storage) { create(:storage, :regular, company: company) }
    let(:incoming_storage) { create(:storage, :incoming, company: company) }

    context 'multiple storage locations' do
      let!(:regular_inventory) { create(:inventory, product: product, storage: regular_storage, value: 50) }
      let!(:incoming_inventory) { create(:inventory, product: product, storage: incoming_storage, value: 30, eta: 7.days.from_now) }

      it 'allows same product in multiple storages' do
        expect(product.inventories.count).to eq(2)
        expect(product.inventories.sum(:value)).to eq(80)
      end

      it 'can find incoming inventory with ETA' do
        incoming = product.inventories.incoming.first
        expect(incoming).to eq(incoming_inventory)
        expect(incoming.eta).to be_present
      end
    end

    context 'default inventory location' do
      let!(:default_inventory) { create(:inventory, product: product, storage: regular_storage, default: true, value: 100) }
      let!(:other_inventory) { create(:inventory, product: product, storage: incoming_storage, default: false, value: 20) }

      it 'marks one location as default' do
        expect(product.inventories.find_by(default: true)).to eq(default_inventory)
      end
    end

    context 'storage deletion' do
      let!(:inventory) { create(:inventory, product: product, storage: regular_storage) }

      it 'is destroyed when storage is destroyed' do
        expect { regular_storage.destroy }.to change { Inventory.count }.by(-1)
      end
    end

    context 'product deletion' do
      let!(:inventory) { create(:inventory, product: product, storage: regular_storage) }

      it 'is destroyed when product is destroyed' do
        expect { product.destroy }.to change { Inventory.count }.by(-1)
      end
    end
  end
end
