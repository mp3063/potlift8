# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncLockable, type: :model do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  after do
    SyncLock.destroy_all
  end

  describe '#sync_locked?' do
    it 'returns false when not locked' do
      expect(product.sync_locked?).to be false
    end

    it 'returns true when locked' do
      lock = SyncLock.acquire(product.send(:sync_lock_key))
      expect(product.sync_locked?).to be true
      lock.release!
    end

    it 'returns false when lock is expired' do
      lock = SyncLock.acquire(product.send(:sync_lock_key))
      lock.update!(updated_at: 10.minutes.ago)

      expect(product.sync_locked?).to be false
      lock.release!
    end

    it 'returns false when lock has been deleted' do
      lock = SyncLock.acquire(product.send(:sync_lock_key))
      lock.destroy

      expect(product.sync_locked?).to be false
    end
  end

  describe '#with_sync_lock' do
    context 'when lock is available' do
      it 'executes the block' do
        executed = false

        result = product.with_sync_lock do
          executed = true
          { data: 'test' }
        end

        expect(executed).to be true
        expect(result).to be_success
        expect(result.data).to eq({ data: 'test' })
      end

      it 'is locked during execution' do
        product.with_sync_lock do
          expect(product.sync_locked?).to be true
        end
      end

      it 'releases lock after successful execution' do
        product.with_sync_lock do
          # Do nothing
        end

        expect(product.sync_locked?).to be false
      end

      it 'returns success result with data' do
        result = product.with_sync_lock do
          { synced: true, timestamp: Time.current }
        end

        expect(result).to be_success
        expect(result.data[:synced]).to be true
      end
    end

    context 'when lock is already held' do
      before do
        @lock = SyncLock.acquire(product.send(:sync_lock_key))
      end

      after do
        @lock&.release!
      end

      it 'does not execute the block' do
        executed = false

        result = product.with_sync_lock do
          executed = true
        end

        expect(executed).to be false
        expect(result).to be_failure
      end

      it 'returns failure result with error message' do
        result = product.with_sync_lock do
          # Won't execute
        end

        expect(result).to be_failure
        expect(result.error).to eq('Resource is currently locked by another process')
      end
    end

    context 'when block raises an error' do
      it 'releases lock after error' do
        begin
          product.with_sync_lock do
            raise StandardError, 'Test error'
          end
        rescue StandardError
          # Expected
        end

        expect(product.sync_locked?).to be false
      end

      it 'returns failure result with error message' do
        result = product.with_sync_lock do
          raise StandardError, 'Test error'
        end

        expect(result).to be_failure
        expect(result.error).to eq('Test error')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Error during locked operation/)

        product.with_sync_lock do
          raise StandardError, 'Test error'
        end
      end
    end
  end

  describe '#sync_lock_time_remaining' do
    it 'returns nil when not locked' do
      expect(product.sync_lock_time_remaining).to be_nil
    end

    it 'returns time remaining when locked' do
      lock = SyncLock.acquire(product.send(:sync_lock_key))

      remaining = product.sync_lock_time_remaining
      expect(remaining).to be > 0
      expect(remaining).to be <= SyncLock::LOCK_TIMEOUT.to_i

      lock.release!
    end

    it 'returns nil for expired locks' do
      lock = SyncLock.acquire(product.send(:sync_lock_key))
      lock.update!(updated_at: 10.minutes.ago)

      expect(product.sync_lock_time_remaining).to be_nil
      lock.release!
    end
  end

  describe 'lock key generation' do
    it 'generates correct lock key format' do
      expected_key = "product:#{product.id}"
      expect(product.send(:sync_lock_key)).to eq(expected_key)
    end

    it 'generates unique keys for different products' do
      product2 = create(:product, company: company, sku: 'TEST-002')

      key1 = product.send(:sync_lock_key)
      key2 = product2.send(:sync_lock_key)

      expect(key1).not_to eq(key2)
    end
  end

  describe 'SyncLockResult' do
    it 'has success? method' do
      result = SyncLockable::SyncLockResult.new(success: true)
      expect(result).to be_success
    end

    it 'has failure? method' do
      result = SyncLockable::SyncLockResult.new(success: false)
      expect(result).to be_failure
    end

    it 'stores error message' do
      result = SyncLockable::SyncLockResult.new(success: false, error: 'Error message')
      expect(result.error).to eq('Error message')
    end

    it 'stores data' do
      data = { key: 'value', timestamp: Time.current }
      result = SyncLockable::SyncLockResult.new(success: true, data: data)
      expect(result.data).to eq(data)
    end
  end
end
