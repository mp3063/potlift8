require 'rails_helper'

RSpec.describe SyncLock, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:sync_lock)).to be_valid
    end

    it 'creates valid sync locks with traits' do
      expect(create(:sync_lock, :recent)).to be_valid
      expect(create(:sync_lock, :old)).to be_valid
      expect(create(:sync_lock, :today)).to be_valid
    end
  end

  # Test validations
  describe 'validations' do
    it { is_expected.to validate_presence_of(:timestamp) }
  end

  # Test associations
  describe 'associations' do
    it 'can have associated products' do
      sync_lock = create(:sync_lock)
      product = create(:product, sync_lock: sync_lock)

      expect(product.sync_lock).to eq(sync_lock)
    end
  end

  # Test timestamp field
  describe 'timestamp field' do
    it 'stores string timestamps' do
      sync_lock = create(:sync_lock, timestamp: '2025-10-10-1500')
      expect(sync_lock.timestamp).to eq('2025-10-10-1500')
    end

    it 'allows various timestamp formats' do
      date_format = create(:sync_lock, timestamp: '2025-10-10')
      datetime_format = create(:sync_lock, timestamp: '2025-10-10-1500')
      iso_format = create(:sync_lock, timestamp: Time.current.iso8601)

      expect(date_format.timestamp).to eq('2025-10-10')
      expect(datetime_format.timestamp).to eq('2025-10-10-1500')
      expect(iso_format.timestamp).to be_present
    end

    it 'requires timestamp to be present' do
      sync_lock = build(:sync_lock, timestamp: nil)
      expect(sync_lock).not_to be_valid
      expect(sync_lock.errors[:timestamp]).to include("can't be blank")
    end

    it 'allows duplicate timestamps' do
      timestamp = '2025-10-10-1200'
      create(:sync_lock, timestamp: timestamp)
      duplicate = build(:sync_lock, timestamp: timestamp)
      expect(duplicate).to be_valid
    end
  end

  # Integration tests
  describe 'integration' do
    let(:sync_lock) { create(:sync_lock, timestamp: '2025-10-10-1200') }

    context 'product synchronization tracking' do
      let(:company) { create(:company) }

      it 'groups products by sync operation' do
        product1 = create(:product, company: company, sync_lock: sync_lock)
        product2 = create(:product, company: company, sync_lock: sync_lock)
        product3 = create(:product, company: company, sync_lock: sync_lock)

        synced_products = Product.where(sync_lock: sync_lock)
        expect(synced_products).to contain_exactly(product1, product2, product3)
      end

      it 'allows products from different syncs' do
        sync1 = create(:sync_lock, timestamp: '2025-10-10-1000')
        sync2 = create(:sync_lock, timestamp: '2025-10-10-1100')

        product1 = create(:product, company: company, sync_lock: sync1)
        product2 = create(:product, company: company, sync_lock: sync2)

        expect(Product.where(sync_lock: sync1)).to contain_exactly(product1)
        expect(Product.where(sync_lock: sync2)).to contain_exactly(product2)
      end

      it 'allows products without sync_lock' do
        product_with_sync = create(:product, company: company, sync_lock: sync_lock)
        product_without_sync = create(:product, company: company, sync_lock: nil)

        expect(product_with_sync.sync_lock).to eq(sync_lock)
        expect(product_without_sync.sync_lock).to be_nil
      end
    end

    context 'sync batch identification' do
      let(:company) { create(:company) }

      it 'identifies all products from a sync batch' do
        batch_sync = create(:sync_lock, :with_products, products_count: 5)
        expect(Product.where(sync_lock: batch_sync).count).to eq(5)
      end

      it 'supports multiple sync operations' do
        morning_sync = create(:sync_lock, timestamp: '2025-10-10-0800')
        noon_sync = create(:sync_lock, timestamp: '2025-10-10-1200')
        evening_sync = create(:sync_lock, timestamp: '2025-10-10-1800')

        create(:product, company: company, sync_lock: morning_sync)
        create(:product, company: company, sync_lock: noon_sync)
        create(:product, company: company, sync_lock: evening_sync)

        expect(Product.where(sync_lock: morning_sync).count).to eq(1)
        expect(Product.where(sync_lock: noon_sync).count).to eq(1)
        expect(Product.where(sync_lock: evening_sync).count).to eq(1)
      end
    end

    context 'sync history tracking' do
      it 'maintains history of sync operations' do
        create(:sync_lock, timestamp: '2025-10-08-1200')
        create(:sync_lock, timestamp: '2025-10-09-1200')
        create(:sync_lock, timestamp: '2025-10-10-1200')

        expect(SyncLock.count).to eq(3)
        timestamps = SyncLock.pluck(:timestamp).sort
        expect(timestamps).to eq(['2025-10-08-1200', '2025-10-09-1200', '2025-10-10-1200'])
      end
    end

    context 'recent vs old syncs' do
      let!(:recent) { create(:sync_lock, :recent) }
      let!(:old) { create(:sync_lock, :old) }

      it 'distinguishes between recent and old syncs' do
        expect(recent.created_at).to be > old.created_at
      end
    end

    context 'sync lock deletion' do
      let(:company) { create(:company) }
      let!(:product) { create(:product, company: company, sync_lock: sync_lock) }

      it 'can be deleted' do
        expect { sync_lock.destroy }.to change { SyncLock.count }.by(-1)
      end

      it 'nullifies product sync_lock_id when deleted' do
        sync_lock.destroy
        expect(product.reload.sync_lock_id).to be_nil
      end
    end

    context 'timestamp formats for different use cases' do
      it 'supports date-only format for daily syncs' do
        sync = create(:sync_lock, timestamp: Date.current.to_s)
        expect(sync.timestamp).to match(/\d{4}-\d{2}-\d{2}/)
      end

      it 'supports datetime format for hourly syncs' do
        sync = create(:sync_lock, timestamp: Time.current.strftime('%Y-%m-%d-%H%M'))
        expect(sync.timestamp).to match(/\d{4}-\d{2}-\d{2}-\d{4}/)
      end

      it 'supports custom format strings' do
        custom_format = "sync-#{Time.current.to_i}"
        sync = create(:sync_lock, timestamp: custom_format)
        expect(sync.timestamp).to eq(custom_format)
      end
    end

    context 'querying sync operations' do
      let(:company) { create(:company) }

      before do
        sync1 = create(:sync_lock, timestamp: '2025-10-10-1000')
        sync2 = create(:sync_lock, timestamp: '2025-10-10-1200')

        create_list(:product, 3, company: company, sync_lock: sync1)
        create_list(:product, 5, company: company, sync_lock: sync2)
      end

      it 'can find products by sync timestamp' do
        sync = SyncLock.find_by(timestamp: '2025-10-10-1000')
        expect(Product.where(sync_lock: sync).count).to eq(3)
      end

      it 'can count products per sync' do
        syncs_with_counts = SyncLock.all.map do |sync|
          [sync.timestamp, Product.where(sync_lock: sync).count]
        end.to_h

        expect(syncs_with_counts['2025-10-10-1000']).to eq(3)
        expect(syncs_with_counts['2025-10-10-1200']).to eq(5)
      end
    end
  end
end
