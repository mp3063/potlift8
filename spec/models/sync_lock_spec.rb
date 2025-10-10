require 'rails_helper'

RSpec.describe SyncLock, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:sync_lock)).to be_valid
    end

    it 'creates valid sync lock' do
      sync_lock = create(:sync_lock)
      expect(sync_lock).to be_persisted
      expect(sync_lock.timestamp).to be_present
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to have_many(:products).dependent(:nullify) }
    it { is_expected.to have_many(:catalogs).dependent(:nullify) }
  end

  # Test validations
  describe 'validations' do
    it { is_expected.to validate_presence_of(:timestamp) }

    it 'validates uniqueness of timestamp' do
      create(:sync_lock, timestamp: 'product:123')
      duplicate = build(:sync_lock, timestamp: 'product:123')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:timestamp]).to include('has already been taken')
    end
  end

  # Test constants
  describe 'constants' do
    it 'defines LOCK_TIMEOUT' do
      expect(SyncLock::LOCK_TIMEOUT).to eq(5.minutes)
    end
  end

  # Test lock lifecycle
  describe '#active?' do
    context 'when lock was recently updated' do
      let(:lock) { create(:sync_lock) }

      it 'returns true' do
        expect(lock.active?).to be true
      end
    end

    context 'when lock is expired (older than LOCK_TIMEOUT)' do
      let(:lock) { create(:sync_lock) }

      before do
        lock.update_column(:updated_at, 6.minutes.ago)
      end

      it 'returns false' do
        expect(lock.active?).to be false
      end
    end

    context 'when lock is exactly at timeout boundary' do
      let(:lock) { create(:sync_lock) }

      before do
        lock.update_column(:updated_at, 5.minutes.ago)
      end

      it 'returns false' do
        expect(lock.active?).to be false
      end
    end
  end

  describe '#expired?' do
    it 'returns opposite of active?' do
      lock = create(:sync_lock)
      expect(lock.expired?).to eq(!lock.active?)

      lock.update_column(:updated_at, 6.minutes.ago)
      expect(lock.expired?).to eq(!lock.active?)
    end
  end

  describe '#refresh!' do
    let(:lock) { create(:sync_lock) }

    it 'updates the timestamp' do
      old_time = lock.updated_at
      sleep 0.01
      lock.refresh!

      expect(lock.updated_at).to be > old_time
    end

    it 'extends the lock period' do
      lock.update_column(:updated_at, 6.minutes.ago)
      expect(lock.active?).to be false

      lock.refresh!
      expect(lock.active?).to be true
    end
  end

  describe '#release!' do
    let(:lock) { create(:sync_lock) }

    it 'destroys the lock record' do
      lock_id = lock.id
      lock.release!

      expect(SyncLock.where(id: lock_id)).not_to exist
    end

    it 'returns true' do
      expect(lock.release!).to be_truthy
    end
  end

  # Test class methods
  describe '.acquire' do
    let(:resource_key) { 'product:123' }

    context 'when no lock exists' do
      it 'creates a new lock' do
        expect {
          SyncLock.acquire(resource_key)
        }.to change { SyncLock.count }.by(1)
      end

      it 'returns the lock' do
        lock = SyncLock.acquire(resource_key)
        expect(lock).to be_a(SyncLock)
        expect(lock.timestamp).to eq(resource_key)
        expect(lock).to be_persisted
      end

      it 'sets the lock as active' do
        lock = SyncLock.acquire(resource_key)
        expect(lock.active?).to be true
      end
    end

    context 'when active lock exists' do
      let!(:existing_lock) { create(:sync_lock, timestamp: resource_key) }

      it 'does not create a new lock' do
        expect {
          SyncLock.acquire(resource_key)
        }.not_to change { SyncLock.count }
      end

      it 'returns nil' do
        result = SyncLock.acquire(resource_key)
        expect(result).to be_nil
      end
    end

    context 'when expired lock exists' do
      let!(:expired_lock) { create(:sync_lock, timestamp: resource_key) }

      before do
        expired_lock.update_column(:updated_at, 6.minutes.ago)
      end

      it 'refreshes the existing lock' do
        expect {
          SyncLock.acquire(resource_key)
        }.not_to change { SyncLock.count }
      end

      it 'returns the refreshed lock' do
        lock = SyncLock.acquire(resource_key)
        expect(lock).to eq(expired_lock.reload)
        expect(lock.active?).to be true
      end

      it 'updates the lock timestamp' do
        old_time = expired_lock.updated_at
        lock = SyncLock.acquire(resource_key)

        expect(lock.updated_at).to be > old_time
      end
    end

    context 'when race condition occurs' do
      let(:resource_key) { 'product:456' }

      it 'handles unique constraint violation gracefully' do
        # Simulate race condition by creating lock while acquiring
        allow(SyncLock).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)

        result = SyncLock.acquire(resource_key)
        expect(result).to be_nil
      end
    end
  end

  describe '.cleanup_expired' do
    let!(:active_lock1) { create(:sync_lock, timestamp: 'product:1') }
    let!(:active_lock2) { create(:sync_lock, timestamp: 'product:2') }
    let!(:expired_lock1) { create(:sync_lock, timestamp: 'product:3') }
    let!(:expired_lock2) { create(:sync_lock, timestamp: 'product:4') }

    before do
      expired_lock1.update_column(:updated_at, 6.minutes.ago)
      expired_lock2.update_column(:updated_at, 10.minutes.ago)
    end

    it 'deletes expired locks' do
      expect {
        SyncLock.cleanup_expired
      }.to change { SyncLock.count }.by(-2)
    end

    it 'keeps active locks' do
      SyncLock.cleanup_expired

      expect(SyncLock.pluck(:id)).to contain_exactly(active_lock1.id, active_lock2.id)
    end

    it 'returns count of deleted locks' do
      deleted_count = SyncLock.cleanup_expired
      expect(deleted_count).to eq(2)
    end
  end

  # Test integration with products and catalogs
  describe 'integration with products' do
    let(:company) { create(:company) }
    let(:sync_lock) { create(:sync_lock, timestamp: '2025-10-10-1500') }
    let!(:product1) { create(:product, company: company, sync_lock: sync_lock) }
    let!(:product2) { create(:product, company: company, sync_lock: sync_lock) }
    let!(:other_product) { create(:product, company: company) }

    it 'groups products by sync operation' do
      synced_products = sync_lock.products
      expect(synced_products).to contain_exactly(product1, product2)
      expect(synced_products).not_to include(other_product)
    end

    it 'nullifies product sync_lock_id on deletion' do
      sync_lock.destroy

      expect(product1.reload.sync_lock_id).to be_nil
      expect(product2.reload.sync_lock_id).to be_nil
    end

    it 'does not destroy products when lock is destroyed' do
      expect {
        sync_lock.destroy
      }.not_to change { Product.count }
    end
  end

  describe 'integration with catalogs' do
    let(:company) { create(:company) }
    let(:sync_lock) { create(:sync_lock, timestamp: '2025-10-10-1500') }
    let!(:catalog1) { create(:catalog, company: company, sync_lock: sync_lock) }
    let!(:catalog2) { create(:catalog, company: company, sync_lock: sync_lock) }

    it 'groups catalogs by sync operation' do
      synced_catalogs = sync_lock.catalogs
      expect(synced_catalogs).to contain_exactly(catalog1, catalog2)
    end

    it 'nullifies catalog sync_lock_id on deletion' do
      sync_lock.destroy

      expect(catalog1.reload.sync_lock_id).to be_nil
      expect(catalog2.reload.sync_lock_id).to be_nil
    end
  end

  # Test historical sync tracking
  describe 'historical sync tracking' do
    let(:company) { create(:company) }

    it 'tracks sync batches with timestamp identifiers' do
      batch1_timestamp = '2025-10-10-1000'
      batch2_timestamp = '2025-10-10-1100'

      lock1 = create(:sync_lock, timestamp: batch1_timestamp)
      lock2 = create(:sync_lock, timestamp: batch2_timestamp)

      product1 = create(:product, company: company, sync_lock: lock1)
      product2 = create(:product, company: company, sync_lock: lock1)
      product3 = create(:product, company: company, sync_lock: lock2)

      batch1_products = company.products.where(sync_lock: lock1)
      batch2_products = company.products.where(sync_lock: lock2)

      expect(batch1_products).to contain_exactly(product1, product2)
      expect(batch2_products).to contain_exactly(product3)
    end
  end

  # Test distributed locking scenarios
  describe 'distributed locking scenarios' do
    it 'prevents concurrent access to same resource' do
      resource_key = 'product:789'

      # First process acquires lock
      lock1 = SyncLock.acquire(resource_key)
      expect(lock1).to be_present
      expect(lock1.active?).to be true

      # Second process tries to acquire same lock
      lock2 = SyncLock.acquire(resource_key)
      expect(lock2).to be_nil

      # After releasing, second process can acquire
      lock1.release!
      lock3 = SyncLock.acquire(resource_key)
      expect(lock3).to be_present
      expect(lock3.active?).to be true
    end

    it 'allows different resources to lock independently' do
      lock1 = SyncLock.acquire('product:100')
      lock2 = SyncLock.acquire('product:200')
      lock3 = SyncLock.acquire('catalog:300')

      expect(lock1).to be_present
      expect(lock2).to be_present
      expect(lock3).to be_present

      expect(lock1.timestamp).to eq('product:100')
      expect(lock2.timestamp).to eq('product:200')
      expect(lock3.timestamp).to eq('catalog:300')
    end

    it 'automatically expires old locks' do
      resource_key = 'product:999'

      # First process acquires lock but doesn't release
      lock1 = SyncLock.acquire(resource_key)
      expect(lock1).to be_present

      # Simulate timeout passing
      lock1.update_column(:updated_at, 6.minutes.ago)

      # Second process can now acquire the expired lock
      lock2 = SyncLock.acquire(resource_key)
      expect(lock2).to be_present
      expect(lock2.active?).to be true
    end
  end
end
