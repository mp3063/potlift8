require 'rails_helper'

RSpec.describe Storage, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:storage)).to be_valid
    end

    it 'creates valid storage with traits' do
      expect(create(:storage, :regular)).to be_valid
      expect(create(:storage, :temporary)).to be_valid
      expect(create(:storage, :incoming)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_many(:inventories).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:inventories) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:storage) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:storage_type) }
    it { is_expected.to validate_presence_of(:storage_status) }

    context 'uniqueness validations' do
      let(:company) { create(:company) }

      before do
        create(:storage, company: company, code: 'WH01')
      end

      it 'validates uniqueness of code scoped to company' do
        duplicate = build(:storage, company: company, code: 'WH01')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different companies' do
        other_company = create(:company)
        storage = build(:storage, company: other_company, code: 'WH01')
        expect(storage).to be_valid
      end

      it 'validates uniqueness case-insensitively' do
        duplicate = build(:storage, company: company, code: 'wh01')
        expect(duplicate).not_to be_valid
      end
    end
  end

  # Test enums
  describe 'enums' do
    describe 'storage_type' do
      it 'defines storage types' do
        expect(Storage.storage_types).to eq({
          'regular' => 1,
          'temporary' => 2,
          'incoming' => 3
        })
      end

      it 'allows setting storage type' do
        storage = create(:storage, storage_type: :regular)
        expect(storage.regular?).to be true
        expect(storage.temporary?).to be false
        expect(storage.incoming?).to be false

        storage.update(storage_type: :incoming)
        expect(storage.incoming?).to be true
        expect(storage.regular?).to be false
      end
    end

    describe 'storage_status' do
      it 'defines storage statuses' do
        expect(Storage.storage_statuses).to eq({
          'deleted' => 0,
          'active' => 1
        })
      end

      it 'allows setting storage status' do
        storage = create(:storage, storage_status: :active)
        expect(storage.active?).to be true
        expect(storage.deleted?).to be false

        storage.update(storage_status: :deleted)
        expect(storage.deleted?).to be true
        expect(storage.active?).to be false
      end

      it 'defaults to active' do
        storage = create(:storage)
        expect(storage.active?).to be true
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    describe '.has_products' do
      let(:company) { create(:company) }
      let!(:storage_with_products) { create(:storage, :with_products, company: company, products_count: 2) }
      let!(:storage_without_products) { create(:storage, company: company) }

      it 'returns storages that have products' do
        result = Storage.has_products
        expect(result).to include(storage_with_products)
        expect(result).not_to include(storage_without_products)
      end
    end

    describe '.order_by_importance' do
      let(:company) { create(:company) }
      let!(:regular_active) { create(:storage, :regular, company: company, storage_status: :active, code: 'REG_A') }
      let!(:regular_deleted) { create(:storage, :regular, company: company, storage_status: :deleted, code: 'REG_D') }
      let!(:temporary_active) { create(:storage, :temporary, company: company, storage_status: :active, code: 'TEMP_A') }
      let!(:incoming_active) { create(:storage, :incoming, company: company, storage_status: :active, code: 'INC_A') }

      it 'orders by storage_type, then status, then id' do
        result = Storage.order_by_importance.to_a

        # Regular type (1) comes before temporary (2) and incoming (3)
        # Active status (1) comes before deleted (0) within same type
        expect(result.index(regular_active)).to be < result.index(regular_deleted)
        expect(result.index(regular_active)).to be < result.index(temporary_active)
        expect(result.index(temporary_active)).to be < result.index(incoming_active)
      end
    end
  end

  # Test instance methods
  describe 'instance methods' do
    describe '#to_param' do
      let(:storage) { create(:storage, code: 'WAREHOUSE-01') }

      it 'returns the code for URL parameter' do
        expect(storage.to_param).to eq('WAREHOUSE-01')
      end
    end

    describe '#total_inventory' do
      let(:company) { create(:company) }
      let(:storage) { create(:storage, company: company) }

      context 'with no inventory' do
        it 'returns 0' do
          expect(storage.total_inventory).to eq(0)
        end
      end

      context 'with inventory records' do
        before do
          create(:inventory, storage: storage, value: 10)
          create(:inventory, storage: storage, value: 25)
          create(:inventory, storage: storage, value: 50)
        end

        it 'returns sum of all inventory values' do
          expect(storage.total_inventory).to eq(85)
        end
      end

      context 'with zero and negative values' do
        before do
          create(:inventory, storage: storage, value: 100)
          create(:inventory, storage: storage, value: 0)
          create(:inventory, storage: storage, value: -10)
        end

        it 'includes all values in the sum' do
          expect(storage.total_inventory).to eq(90)
        end
      end
    end

    describe '#product_count' do
      let(:company) { create(:company) }
      let(:storage) { create(:storage, company: company) }

      context 'with no inventory' do
        it 'returns 0' do
          expect(storage.product_count).to eq(0)
        end
      end

      context 'with inventory records' do
        before do
          create(:inventory, storage: storage, value: 10)
          create(:inventory, storage: storage, value: 25)
          create(:inventory, storage: storage, value: 0)
        end

        it 'counts only inventories with value > 0' do
          expect(storage.product_count).to eq(2)
        end
      end

      context 'with negative values' do
        before do
          create(:inventory, storage: storage, value: 10)
          create(:inventory, storage: storage, value: -5)
        end

        it 'does not count negative values' do
          expect(storage.product_count).to eq(1)
        end
      end

      context 'with only zero values' do
        before do
          create(:inventory, storage: storage, value: 0)
          create(:inventory, storage: storage, value: 0)
        end

        it 'returns 0' do
          expect(storage.product_count).to eq(0)
        end
      end
    end

    describe '#has_inventory?' do
      let(:company) { create(:company) }
      let(:storage) { create(:storage, company: company) }

      context 'with no inventory' do
        it 'returns false' do
          expect(storage.has_inventory?).to be false
        end
      end

      context 'with inventory value > 0' do
        before do
          create(:inventory, storage: storage, value: 10)
        end

        it 'returns true' do
          expect(storage.has_inventory?).to be true
        end
      end

      context 'with only zero inventory values' do
        before do
          create(:inventory, storage: storage, value: 0)
        end

        it 'returns false' do
          expect(storage.has_inventory?).to be false
        end
      end

      context 'with mixed values' do
        before do
          create(:inventory, storage: storage, value: 0)
          create(:inventory, storage: storage, value: 10)
        end

        it 'returns true if any value > 0' do
          expect(storage.has_inventory?).to be true
        end
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores custom metadata' do
        storage = create(:storage, :with_info)
        expect(storage.info['location']).to eq('Building A')
        expect(storage.info['capacity']).to eq(1000)
      end

      it 'defaults to empty hash' do
        storage = create(:storage)
        expect(storage.info).to eq({})
      end

      it 'allows updating info' do
        storage = create(:storage)
        storage.update(info: { 'custom_field' => 'value' })
        expect(storage.reload.info['custom_field']).to eq('value')
      end
    end
  end

  # Test default values
  describe 'default values' do
    let(:storage) { create(:storage) }

    it 'sets default to false by default' do
      expect(storage.default).to be false
    end

    it 'allows setting default storage' do
      storage.update(default: true)
      expect(storage.reload.default).to be true
    end
  end

  # Test storage position
  describe 'storage_position' do
    it 'allows nil position' do
      storage = create(:storage, storage_position: nil)
      expect(storage.storage_position).to be_nil
    end

    it 'allows setting position' do
      storage = create(:storage, :positioned)
      expect(storage.storage_position).to be_a(Integer)
      expect(storage.storage_position).to be > 0
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:storage) { create(:storage, company: company) }

    context 'when storage has products' do
      let!(:product1) { create(:product, company: company) }
      let!(:product2) { create(:product, company: company) }
      let!(:inventory1) { create(:inventory, storage: storage, product: product1, value: 10) }
      let!(:inventory2) { create(:inventory, storage: storage, product: product2, value: 20) }

      it 'can access products through inventories' do
        expect(storage.products).to contain_exactly(product1, product2)
      end

      it 'destroys inventories when storage is destroyed' do
        expect { storage.destroy }.to change { Inventory.count }.by(-2)
      end
    end

    context 'storage lifecycle' do
      it 'can transition from active to deleted' do
        expect(storage.active?).to be true
        storage.update(storage_status: :deleted)
        expect(storage.reload.deleted?).to be true
      end

      it 'can change storage type' do
        expect(storage.regular?).to be true
        storage.update(storage_type: :incoming)
        expect(storage.reload.incoming?).to be true
      end
    end
  end
end
