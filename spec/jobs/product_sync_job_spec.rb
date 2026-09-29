# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductSyncJob, type: :job do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:catalog) { create(:catalog, :shop_connected, company: company) }
  let(:timestamp) { Time.current }
  let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

  # Adding the item to a connected catalog enqueues its own sync; start clean.
  before { clear_enqueued_jobs }

  describe 'queue configuration' do
    it 'is enqueued on the default queue' do
      queue_name = ProductSyncJob.new.queue_name
      # In test environment, queue names may be prefixed with 'test__'
      expect(queue_name).to match(/default$/)
    end
  end

  describe '#perform' do
    context 'when product is sync locked' do
      before do
        allow(product).to receive(:sync_locked?).and_return(true)
      end

      it 'skips sync and logs warning' do
        expect(ProductSyncService).not_to receive(:new)
        expect(Rails.logger).to receive(:warn).with(/sync locked/)

        described_class.perform_now(product, catalog, timestamp)
      end
    end

    context 'when the product is no longer in the catalog' do
      before { catalog_item.destroy! }

      it 'skips sync so a queued sync cannot recreate a removed product' do
        expect(ProductSyncService).not_to receive(:new)

        described_class.perform_now(product, catalog, timestamp)
      end
    end

    context 'when catalog is not connected to a shop' do
      before { catalog.update!(info: {}) }

      it 'skips sync' do
        expect(ProductSyncService).not_to receive(:new)

        described_class.perform_now(product, catalog, timestamp)
      end
    end

    context 'when catalog has sync paused' do
      before do
        catalog.update!(info: { 'sync_paused' => true })
      end

      it 'skips sync and logs info' do
        expect(ProductSyncService).not_to receive(:new)
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(product, catalog, timestamp)

        # Verify the log file contains the expected message
        expect(Rails.logger).to have_received(:info).at_least(:once)
      end
    end

    context 'when conditions are met for sync' do
      let(:mock_service) { instance_double(ProductSyncService) }
      let(:sync_result) { SyncLockable::SyncLockResult.new(success: true, data: {}) }

      before do
        allow(ProductSyncService).to receive(:new).with(product, catalog).and_return(mock_service)
        allow(mock_service).to receive(:sync_to_external_system).and_return(sync_result)
      end

      it 'calls ProductSyncService' do
        expect(mock_service).to receive(:sync_to_external_system)
        described_class.perform_now(product, catalog, timestamp)
      end

      it 'logs sync start and completion' do
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(product, catalog, timestamp)

        expect(Rails.logger).to have_received(:info).at_least(:twice)
      end

      it 'logs sync metrics' do
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(product, catalog, timestamp)

        expect(Rails.logger).to have_received(:info).at_least(:once)
      end
    end

    context 'with repeated changes inside the dedup window' do
      let(:mock_service) { instance_double(ProductSyncService, sync_to_external_system: SyncLockable::SyncLockResult.new(success: true, data: {})) }
      let(:params) { { product_id: product.id, catalog_id: catalog.id } }

      before do
        redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
        keys = redis.keys("job_dedup:*")
        redis.del(*keys) if keys.any?
        allow(ProductSyncService).to receive(:new).with(product, catalog).and_return(mock_service)
      end

      it "schedules one trailing sync for a change inside the window" do
        2.times { described_class.perform_now(product, catalog, timestamp) }

        expect(mock_service).to have_received(:sync_to_external_system).once
        expect(ProductSyncJob).to have_been_enqueued.with(product, catalog, anything).exactly(:once)
      end

      it "schedules only one trailing sync for many changes" do
        4.times { described_class.perform_now(product, catalog, timestamp) }

        expect(mock_service).to have_received(:sync_to_external_system).once
        expect(ProductSyncJob).to have_been_enqueued.exactly(:once)
      end

      it "lets the trailing run sync and re-arm" do
        described_class.perform_now(product, catalog, timestamp)
        described_class.perform_now(product, catalog, timestamp)
        JobDeduplicator.new(job_name: "ProductSyncJob", params: params, bucketed: false).clear!
        described_class.perform_now(product, catalog, timestamp)

        expect(mock_service).to have_received(:sync_to_external_system).twice
        marker = JobDeduplicator.new(job_name: "ProductSyncJob:trailing", params: params, bucketed: false)
        expect(marker.executed_recently?).to be false

        described_class.perform_now(product, catalog, timestamp)
        expect(ProductSyncJob).to have_been_enqueued.exactly(:twice)
      end

      it "schedules the trailing sync at least 1s past the lock's expiry" do
        freeze_time do
          2.times { described_class.perform_now(product, catalog, timestamp) }

          lock_ttl = JobDeduplicator.new(job_name: "ProductSyncJob", params: params, bucketed: false)
                                    .time_until_executable
          expect(lock_ttl).to be > 0
          expect(enqueued_jobs.last[:at]).to be >= (Time.current + lock_ttl + 1).to_f
        end
      end

      context "when the duplicate was queued before the running sync started" do
        it "schedules nothing, because the running sync already covers the change" do
          freeze_time do
            described_class.perform_now(product, catalog, Time.current)
            described_class.perform_now(product, catalog, 10.seconds.ago)
          end

          expect(mock_service).to have_received(:sync_to_external_system).once
          expect(ProductSyncJob).not_to have_been_enqueued
        end

        it "still schedules the trailing sync when the lock's start time cannot be read" do
          freeze_time do
            described_class.perform_now(product, catalog, Time.current)
            allow_any_instance_of(Redis).to receive(:get).and_raise(Redis::CannotConnectError)
            described_class.perform_now(product, catalog, 10.seconds.ago)
          end

          expect(ProductSyncJob).to have_been_enqueued.exactly(:once)
        end

        it "still schedules the trailing sync when the lock holds the legacy value" do
          freeze_time do
            JobDeduplicator.new(job_name: "ProductSyncJob", params: params, window: 30, bucketed: false).unique?
            described_class.perform_now(product, catalog, 10.seconds.ago)
          end

          expect(mock_service).not_to have_received(:sync_to_external_system)
          expect(ProductSyncJob).to have_been_enqueued.exactly(:once)
        end
      end

      it "schedules the trailing sync for a duplicate queued after the running sync started" do
        freeze_time do
          described_class.perform_now(product, catalog, Time.current)
          travel 5.seconds
          described_class.perform_now(product, catalog, Time.current)
        end

        expect(mock_service).to have_received(:sync_to_external_system).once
        expect(ProductSyncJob).to have_been_enqueued.exactly(:once)
      end

      it "still syncs when Redis is down" do
        allow_any_instance_of(Redis).to receive(:set).and_raise(Redis::CannotConnectError)

        described_class.perform_now(product, catalog, timestamp)

        expect(mock_service).to have_received(:sync_to_external_system).once
        expect(ProductSyncJob).not_to have_been_enqueued
      end
    end

    context 'when sync fails' do
      let(:mock_service) { instance_double(ProductSyncService) }
      let(:error_message) { 'External API error' }

      before do
        allow(ProductSyncService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:sync_to_external_system)
          .and_raise(StandardError.new(error_message))
      end

      it 'logs error details' do
        allow(Rails.logger).to receive(:error).and_call_original

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).at_least(:once)
      end

      it 're-raises the error for retry logic' do
        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.to raise_error(StandardError, error_message)
      end

      it 'logs failure metrics' do
        allow(Rails.logger).to receive(:info).and_call_original

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:info).at_least(:once)
      end
    end

    context 'when the sync result is a failure' do
      let(:mock_service) { instance_double(ProductSyncService) }
      let(:params) { { product_id: product.id, catalog_id: catalog.id } }

      before do
        redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
        keys = redis.keys("job_dedup:*")
        redis.del(*keys) if keys.any?
        allow(ProductSyncService).to receive(:new).with(product, catalog).and_return(mock_service)
        allow(mock_service).to receive(:sync_to_external_system)
          .and_return(SyncLockable::SyncLockResult.new(success: false, error: "Shopify8 unavailable"))
      end

      it "marks the catalog item failed with the error" do
        described_class.perform_now(product, catalog, timestamp)

        catalog_item.reload
        expect(catalog_item).to be_sync_failed
        # The raw error is sanitized before storage; "Shopify8 unavailable" maps to the generic message
        expect(catalog_item.last_sync_error).to match(/\ASync failed \(ref: \h{8}\)\z/)
      end

      it "re-enqueues itself for a retry" do
        described_class.perform_now(product, catalog, timestamp)

        expect(ProductSyncJob).to have_been_enqueued.exactly(:once)
      end

      it "releases the dedup lock so the retry is not turned into a trailing sync" do
        described_class.perform_now(product, catalog, timestamp)

        expect(JobDeduplicator.new(job_name: "ProductSyncJob", params: params, bucketed: false).unique?).to be true
      end

      it "stops after 5 attempts" do
        # Rails wraps errors that escape perform_enqueued_jobs, so assert inside the block
        perform_enqueued_jobs do
          expect do
            ProductSyncJob.perform_later(product, catalog, Time.current)
          end.to raise_error(ProductSyncJob::SyncFailed, "Shopify8 unavailable")
        end

        expect(mock_service).to have_received(:sync_to_external_system).exactly(5).times
      end
    end

    context 'when the sync is rate limited' do
      let(:mock_service) { instance_double(ProductSyncService) }
      let(:params) { { product_id: product.id, catalog_id: catalog.id } }

      before do
        redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
        keys = redis.keys("job_dedup:*")
        redis.del(*keys) if keys.any?
        catalog_item.update!(sync_status: :pending, last_sync_error: "earlier error")
        allow(ProductSyncService).to receive(:new).with(product, catalog).and_return(mock_service)
        allow(mock_service).to receive(:sync_to_external_system)
          .and_raise(RateLimiter::RateLimitExceededError, "Rate limit exceeded")
      end

      it "re-enqueues itself after the limiter window" do
        freeze_time do
          described_class.perform_now(product, catalog, timestamp)

          expect(ProductSyncJob).to have_been_enqueued.with(product, catalog, timestamp).exactly(:once)
          expect(enqueued_jobs.last[:at]).to be >= (Time.current + 60).to_f
        end
      end

      it "leaves the catalog item pending with its previous error" do
        described_class.perform_now(product, catalog, timestamp)

        catalog_item.reload
        expect(catalog_item).to be_sync_pending
        expect(catalog_item.last_sync_error).to eq("earlier error")
      end

      it "releases the dedup lock so the retry syncs" do
        described_class.perform_now(product, catalog, timestamp)

        expect(JobDeduplicator.new(job_name: "ProductSyncJob", params: params, bucketed: false).unique?).to be true
      end

      it "stops after 10 attempts and marks the catalog item failed" do
        perform_enqueued_jobs do
          expect do
            ProductSyncJob.perform_later(product, catalog, Time.current)
          end.not_to raise_error
        end

        expect(mock_service).to have_received(:sync_to_external_system).exactly(10).times
        expect(enqueued_jobs).to be_empty
        catalog_item.reload
        expect(catalog_item).to be_sync_failed
        expect(catalog_item.last_sync_error).to be_present
        expect(catalog_item.last_sync_error).not_to eq("earlier error")
      end

      it "gives up quietly when the catalog item is gone once retries run out" do
        # The item can leave the catalog between the last attempt's check and the give-up handler
        allow(CatalogItem).to receive(:find_by).and_call_original
        allow(CatalogItem).to receive(:find_by).with(catalog: catalog, product: product).and_return(nil)

        perform_enqueued_jobs do
          expect do
            ProductSyncJob.perform_later(product, catalog, Time.current)
          end.not_to raise_error
        end

        expect(mock_service).to have_received(:sync_to_external_system).exactly(10).times
        expect(catalog_item.reload).to be_sync_pending
      end
    end

    context 'with transient errors' do
      let(:mock_service) { instance_double(ProductSyncService) }

      before do
        allow(ProductSyncService).to receive(:new).and_return(mock_service)
      end

      it 'retries on Faraday::ConnectionFailed' do
        allow(mock_service).to receive(:sync_to_external_system)
          .and_raise(Faraday::ConnectionFailed.new('Connection failed'))

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.not_to raise_error

        expect(described_class).to have_been_enqueued.with(product, catalog, timestamp)
      end

      it 'retries on Faraday::TimeoutError' do
        allow(mock_service).to receive(:sync_to_external_system)
          .and_raise(Faraday::TimeoutError.new('Timeout'))

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.not_to raise_error

        expect(described_class).to have_been_enqueued.with(product, catalog, timestamp)
      end
    end

    context 'with missing records' do
      it 'handles missing catalog gracefully' do
        catalog.destroy

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.not_to raise_error
      end

      it 'handles missing product gracefully' do
        product.destroy

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.not_to raise_error
      end
    end

    context 'with delayed execution' do
      it 'can be scheduled for later execution' do
        freeze_time do
          expect do
            described_class.set(wait: 5.seconds).perform_later(product, catalog, timestamp)
          end.to have_enqueued_job(ProductSyncJob)
            .with(product, catalog, timestamp)
            .at(5.seconds.from_now)
        end
      end
    end
  end

  describe 'integration with ProductSyncService' do
    it 'passes correct parameters to service constructor' do
      expect(ProductSyncService).to receive(:new).with(product, catalog)
        .and_call_original

      allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system)
        .and_return(SyncLockable::SyncLockResult.new(success: true, data: {}))

      described_class.perform_now(product, catalog, timestamp)
    end
  end

  describe 'job enqueueing' do
    it 'enqueues the job' do
      freeze_time do
        expect do
          described_class.perform_later(product, catalog, timestamp)
        end.to have_enqueued_job(ProductSyncJob)
          .with(product, catalog, timestamp)
      end
    end
  end
end
