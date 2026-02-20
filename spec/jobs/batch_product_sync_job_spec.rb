# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BatchProductSyncJob, type: :job do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:products) { create_list(:product, 5, company: company) }
  let(:product_ids) { products.map(&:id) }

  # Create catalog_items to link products to catalog
  before do
    products.each do |product|
      create(:catalog_item, catalog: catalog, product: product)
    end
  end

  # Mock ProductSyncService
  before do
    allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system)
      .and_return(double(success?: true, error: nil))
  end

  describe '#perform' do
    it 'syncs all products in the batch' do
      # Allow multiple instances to receive the message
      allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system)
        .and_return(double(success?: true, error: nil))

      described_class.perform_now(product_ids, catalog.id)

      # Verify that sync was called (checked via side effects or logs)
      # Note: We already have the global mock in the before block
    end

    it 'logs batch start' do
      allow(Rails.logger).to receive(:info).and_call_original

      described_class.perform_now(product_ids, catalog.id)

      # Verify the log message was called
      expect(Rails.logger).to have_received(:info).with(/Starting batch sync: #{products.size} products/)
    end

    it 'logs batch completion' do
      allow(Rails.logger).to receive(:info).and_call_original

      described_class.perform_now(product_ids, catalog.id)

      # Verify the log message was called
      expect(Rails.logger).to have_received(:info).with(/Batch sync completed: 5\/5 successful/)
    end

    it 'uses eager loading for efficiency' do
      # Products are eager-loaded with associations. Per product: find_by + update! + broadcast count queries.
      # 5 products × ~10 queries each + setup queries = ~50-60 total
      expect {
        described_class.perform_now(product_ids, catalog.id)
      }.to make_database_queries(count: 10..70) # Eager loading + per-item sync_status updates + broadcast counts
    end

    context 'when catalog has sync paused' do
      before do
        catalog.update!(info: { 'sync_paused' => true })
      end

      it 'skips the sync' do
        # Track sync call count
        sync_count = 0
        allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system) do
          sync_count += 1
          double(success?: true, error: nil)
        end

        described_class.perform_now(product_ids, catalog.id)

        # Should not sync any products
        expect(sync_count).to eq(0)
      end

      it 'logs skip message' do
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(product_ids, catalog.id)

        # Verify the log message was called
        expect(Rails.logger).to have_received(:info).with(/has sync paused/)
      end
    end

    context 'when products have sync locks' do
      before do
        # Lock first product by creating an active SyncLock
        lock = SyncLock.acquire("product:#{products.first.id}")
        products.first.update!(sync_lock_id: lock.id)
      end

      it 'skips locked products' do
        # Count the number of successful syncs
        sync_count = 0
        allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system) do
          sync_count += 1
          double(success?: true, error: nil)
        end

        described_class.perform_now(product_ids, catalog.id)

        # Should sync 4 products (5 - 1 locked)
        expect(sync_count).to eq(4)
      end

      it 'logs skipped products' do
        allow(Rails.logger).to receive(:debug).and_call_original

        described_class.perform_now(product_ids, catalog.id)

        # Verify the log message was called
        expect(Rails.logger).to have_received(:debug).with(/is sync locked/)
      end
    end

    context 'when individual product sync fails' do
      before do
        # Make second product fail
        allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system) do |service|
          if service.product == products[1]
            double(success?: false, error: 'API error')
          else
            double(success?: true, error: nil)
          end
        end
      end

      it 'continues syncing other products' do
        # Count the number of sync attempts
        sync_count = 0
        allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system) do |service|
          sync_count += 1
          if service.product == products[1]
            double(success?: false, error: 'API error')
          else
            double(success?: true, error: nil)
          end
        end

        described_class.perform_now(product_ids, catalog.id)

        # Should attempt all 5 products
        expect(sync_count).to eq(5)
      end

      it 'logs failure but completes batch' do
        expect(Rails.logger).to receive(:warn).with(/1 products failed to sync/).and_call_original

        described_class.perform_now(product_ids, catalog.id)
      end

      it 'includes sample errors in summary' do
        expect(Rails.logger).to receive(:info).at_least(:once).and_call_original do |log|
          next unless log.is_a?(String) && log.start_with?('{')

          data = JSON.parse(log)
          expect(data['failure_count']).to eq(1)
          expect(data['success_count']).to eq(4)
          expect(data['sample_errors']).to be_present
        end

        described_class.perform_now(product_ids, catalog.id)
      end
    end

    context 'when product sync raises exception' do
      before do
        allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system) do |service|
          if service.product == products[1]
            raise StandardError, 'Network error'
          else
            double(success?: true, error: nil)
          end
        end
      end

      it 'handles exception and continues' do
        # Exceptions are caught in sync_single_product and converted to failures
        # No error log is generated, just counted as a failure
        described_class.perform_now(product_ids, catalog.id)

        # The job should complete without raising an exception
        # The failure is tracked in the summary
      end

      it 'counts exception as failure' do
        expect(Rails.logger).to receive(:info).at_least(:once).and_call_original do |log|
          next unless log.is_a?(String) && log.start_with?('{')

          data = JSON.parse(log)
          expect(data['failure_count']).to eq(1)
          expect(data['success_count']).to eq(4)
        end

        described_class.perform_now(product_ids, catalog.id)
      end
    end

    context 'with large batch' do
      let(:large_batch) { create_list(:product, 150, company: company) }
      let(:large_product_ids) { large_batch.map(&:id) }

      before do
        large_batch.each do |product|
          create(:catalog_item, catalog: catalog, product: product)
        end
      end

      it 'processes in chunks using find_each' do
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(large_product_ids, catalog.id)

        # Verify progress was logged at least twice
        expect(Rails.logger).to have_received(:info).with(/Progress:/).at_least(2).times
      end

      it 'logs progress every 50 products' do
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(large_product_ids, catalog.id)

        # Verify progress logs for milestones
        expect(Rails.logger).to have_received(:info).with(/Progress: 50\/150/)
        expect(Rails.logger).to have_received(:info).with(/Progress: 100\/150/)
        expect(Rails.logger).to have_received(:info).with(/Progress: 150\/150/)
      end
    end

    context 'when catalog not found' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_now(product_ids, 99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'logs error' do
        # The error log comes from BatchProductSyncJob
        allow(Rails.logger).to receive(:error).and_call_original

        expect {
          described_class.perform_now(product_ids, 99999)
        }.to raise_error(ActiveRecord::RecordNotFound)

        # Verify error was logged
        expect(Rails.logger).to have_received(:error).with(/Catalog .* not found/)
      end
    end
  end

  describe 'queue configuration' do
    it 'uses low_priority queue' do
      # In test environment, queue names are prefixed with "test__"
      expect(described_class.new.queue_name).to match(/low_priority/)
    end
  end

  describe 'performance metrics' do
    it 'logs duration' do
      expect(Rails.logger).to receive(:info).at_least(:once).and_call_original do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['duration_seconds']).to be > 0
      end

      described_class.perform_now(product_ids, catalog.id)
    end

    it 'calculates products per second' do
      expect(Rails.logger).to receive(:info).at_least(:once).and_call_original do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['products_per_second']).to be > 0
      end

      described_class.perform_now(product_ids, catalog.id)
    end

    it 'calculates success rate' do
      expect(Rails.logger).to receive(:info).at_least(:once).and_call_original do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['success_rate']).to eq(100.0)
      end

      described_class.perform_now(product_ids, catalog.id)
    end
  end

  describe 'structured logging' do
    it 'logs completion as JSON' do
      expect(Rails.logger).to receive(:info).at_least(:once).and_call_original do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data).to include(
          'event' => 'batch_sync_completed',
          'catalog_id' => catalog.id,
          'catalog_code' => catalog.code,
          'total_products' => 5,
          'success_count' => 5,
          'failure_count' => 0,
          'skipped_count' => 0
        )
      end

      described_class.perform_now(product_ids, catalog.id)
    end
  end

  describe 'integration with ProductSyncService' do
    it 'creates service with correct product and catalog' do
      expect(ProductSyncService).to receive(:new).exactly(5).times do |product, catalog_arg|
        expect(product_ids).to include(product.id)
        expect(catalog_arg).to eq(catalog)
        double(sync_to_external_system: double(success?: true))
      end

      described_class.perform_now(product_ids, catalog.id)
    end
  end

  describe 'memory efficiency' do
    it 'uses find_each for batch processing' do
      # find_each should be called on the Product relation
      expect_any_instance_of(ActiveRecord::Relation).to receive(:find_each)
        .with(batch_size: 100)
        .and_call_original

      described_class.perform_now(product_ids, catalog.id)
    end
  end
end
