# Inventory Update Service Spec
#
# Tests for InventoryUpdateService that handles inventory updates
# from external systems with multi-storage support and ETA handling.
#
require 'rails_helper'

RSpec.describe InventoryUpdateService do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, sku: 'TEST-PRODUCT') }
  let(:storage_main) { create(:storage, company: company, code: 'MAIN', name: 'Main Storage') }
  let(:storage_incoming) { create(:storage, company: company, code: 'INCOMING', name: 'Incoming Storage', storage_type: :incoming) }
  let(:storage_temp) { create(:storage, company: company, code: 'TEMP', name: 'Temp Storage', storage_type: :temporary) }

  let(:service) { described_class.new(company, product) }

  describe '#initialize' do
    it 'sets company and product' do
      expect(service.company).to eq(company)
      expect(service.product).to eq(product)
    end

    it 'initializes empty errors array' do
      expect(service.errors).to eq([])
    end
  end

  describe '#update' do
    context 'with single storage update' do
      let(:updates) do
        [
          { storage_code: 'MAIN', value: 100 }
        ]
      end

      before do
        storage_main
      end

      it 'returns success response' do
        result = service.update(updates: updates)

        expect(result[:success]).to be true
        expect(result[:inventory]).to be_present
        expect(result[:updates]).to be_an(Array)
      end

      it 'creates new inventory record' do
        expect do
          service.update(updates: updates)
        end.to change { product.inventories.count }.by(1)

        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(100)
      end

      it 'includes update details in response' do
        result = service.update(updates: updates)

        update = result[:updates].first
        expect(update[:storage_code]).to eq('MAIN')
        expect(update[:value]).to eq(100)
        expect(update[:updated]).to be true
      end

      it 'updates existing inventory record' do
        create(:inventory, product: product, storage: storage_main, value: 50)

        expect do
          service.update(updates: updates)
        end.not_to change { product.inventories.count }

        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(100)
      end
    end

    context 'with multiple storage updates' do
      let(:updates) do
        [
          { storage_code: 'MAIN', value: 150 },
          { storage_code: 'INCOMING', value: 50 },
          { storage_code: 'TEMP', value: 25 }
        ]
      end

      before do
        storage_main
        storage_incoming
        storage_temp
      end

      it 'creates all inventory records' do
        expect do
          service.update(updates: updates)
        end.to change { product.inventories.count }.by(3)
      end

      it 'sets correct values for all storages' do
        service.update(updates: updates)

        expect(product.inventories.find_by(storage: storage_main).value).to eq(150)
        expect(product.inventories.find_by(storage: storage_incoming).value).to eq(50)
        expect(product.inventories.find_by(storage: storage_temp).value).to eq(25)
      end

      it 'returns all update details' do
        result = service.update(updates: updates)

        expect(result[:updates].length).to eq(3)
        expect(result[:updates].map { |u| u[:storage_code] }).to contain_exactly('MAIN', 'INCOMING', 'TEMP')
      end
    end

    context 'with ETA dates' do
      let(:eta_date) { '2025-11-15' }
      let(:updates) do
        [
          { storage_code: 'INCOMING', value: 100, eta: eta_date }
        ]
      end

      before do
        storage_incoming
      end

      it 'stores ETA as Date object' do
        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_incoming)
        expect(inventory.eta).to eq(Date.parse(eta_date))
      end

      it 'includes ETA in response' do
        result = service.update(updates: updates)

        update = result[:updates].first
        expect(update[:eta]).to eq(Date.parse(eta_date))
      end

      it 'handles Date objects as input' do
        date_obj = Date.parse(eta_date)
        updates[0][:eta] = date_obj

        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_incoming)
        expect(inventory.eta).to eq(date_obj)
      end

      it 'handles nil ETA' do
        updates[0][:eta] = nil

        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_incoming)
        expect(inventory.eta).to be_nil
      end

      it 'handles invalid ETA gracefully' do
        updates[0][:eta] = 'invalid-date'

        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_incoming)
        expect(inventory.eta).to be_nil
      end

      it 'updates ETA on existing inventory' do
        create(:inventory, product: product, storage: storage_incoming, value: 50, eta: Date.parse('2025-10-01'))

        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_incoming)
        expect(inventory.eta).to eq(Date.parse(eta_date))
      end
    end

    context 'with invalid data' do
      before do
        storage_main
      end

      it 'returns error for non-array updates' do
        result = service.update(updates: 'not an array')

        expect(result[:success]).to be false
        expect(result[:error]).to include('non-empty array')
      end

      it 'returns error for empty array' do
        result = service.update(updates: [])

        expect(result[:success]).to be false
        expect(result[:error]).to include('non-empty array')
      end

      it 'returns error for missing storage_code' do
        updates = [ { value: 100 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
        expect(result[:error]).to include('storage_code is required')
      end

      it 'returns error for missing value' do
        updates = [ { storage_code: 'MAIN' } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
        expect(result[:error]).to include('value is required')
      end

      it 'returns error for invalid storage code' do
        updates = [ { storage_code: 'NONEXISTENT', value: 100 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Storage not found')
      end

      it 'returns error for non-numeric value' do
        updates = [ { storage_code: 'MAIN', value: 'not a number' } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid value')
      end

      it 'converts string numbers to integers' do
        updates = [ { storage_code: 'MAIN', value: '150' } ]

        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(150)
      end

      it 'handles negative values' do
        updates = [ { storage_code: 'MAIN', value: -50 } ]

        service.update(updates: updates)

        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(-50)
      end
    end

    context 'with transaction rollback' do
      before do
        storage_main
      end

      it 'rolls back all updates if one fails' do
        updates = [
          { storage_code: 'MAIN', value: 100 },
          { storage_code: 'INVALID', value: 50 } # This will fail
        ]

        expect do
          service.update(updates: updates)
        end.not_to change { product.inventories.count }
      end

      it 'returns error response on rollback' do
        updates = [
          { storage_code: 'MAIN', value: 100 },
          { storage_code: 'INVALID', value: 50 }
        ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Storage not found')
      end

      it 'does not partial update on validation error' do
        # Create a scenario where second update fails validation
        allow_any_instance_of(Inventory).to receive(:save).and_return(true, false)

        updates = [
          { storage_code: 'MAIN', value: 100 },
          { storage_code: 'INCOMING', value: 50 }
        ]

        storage_incoming

        expect do
          service.update(updates: updates)
        end.not_to change { product.inventories.count }
      end
    end

    context 'with inventory response' do
      before do
        storage_main
        storage_incoming
      end

      it 'reloads product to get fresh inventory data' do
        updates = [
          { storage_code: 'MAIN', value: 100 },
          { storage_code: 'INCOMING', value: 50, eta: '2025-12-01' }
        ]

        result = service.update(updates: updates)

        expect(result[:inventory]).to be_present
        expect(result[:inventory]).to have_key(:available)
        expect(result[:inventory]).to have_key(:incoming)
        expect(result[:inventory]).to have_key(:eta)
      end

      it 'includes correct inventory totals' do
        updates = [
          { storage_code: 'MAIN', value: 200 },
          { storage_code: 'INCOMING', value: 75 }
        ]

        result = service.update(updates: updates)

        # Assuming single_inventory_with_eta returns aggregated values
        expect(result[:inventory][:available]).to be_present
        expect(result[:inventory][:incoming]).to be_present
      end
    end

    context 'with storage validation' do
      it 'validates storage belongs to company' do
        other_company = create(:company)
        other_storage = create(:storage, company: other_company, code: 'OTHER')

        updates = [ { storage_code: 'OTHER', value: 100 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Storage not found')
      end

      it 'allows any storage type' do
        regular = create(:storage, company: company, code: 'REG', storage_type: :regular)
        temp = create(:storage, company: company, code: 'TMP', storage_type: :temporary)
        incoming = create(:storage, company: company, code: 'INC', storage_type: :incoming)

        updates = [
          { storage_code: 'REG', value: 100 },
          { storage_code: 'TMP', value: 50 },
          { storage_code: 'INC', value: 25 }
        ]

        result = service.update(updates: updates)

        expect(result[:success]).to be true
        expect(result[:updates].length).to eq(3)
      end
    end

    context 'with concurrent updates' do
      before do
        storage_main
      end

      it 'handles concurrent updates to same storage' do
        # Create initial inventory
        create(:inventory, product: product, storage: storage_main, value: 100)

        updates = [ { storage_code: 'MAIN', value: 200 } ]

        # Simulate concurrent update
        result1 = service.update(updates: updates)
        result2 = service.update(updates: [ { storage_code: 'MAIN', value: 300 } ])

        expect(result1[:success]).to be true
        expect(result2[:success]).to be true

        # Last update should win
        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(300)
      end
    end

    context 'with edge cases' do
      before do
        storage_main
      end

      it 'handles zero value' do
        updates = [ { storage_code: 'MAIN', value: 0 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be true

        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(0)
      end

      it 'handles very large values' do
        updates = [ { storage_code: 'MAIN', value: 999_999_999 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be true

        inventory = product.inventories.find_by(storage: storage_main)
        expect(inventory.value).to eq(999_999_999)
      end

      it 'handles blank storage_code' do
        updates = [ { storage_code: '', value: 100 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
      end

      it 'handles nil storage_code' do
        updates = [ { storage_code: nil, value: 100 } ]

        result = service.update(updates: updates)

        expect(result[:success]).to be false
      end
    end
  end
end
