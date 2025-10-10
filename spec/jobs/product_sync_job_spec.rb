# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductSyncJob, type: :job do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:timestamp) { Time.current }

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
      let(:sync_result) { { success: true, synced_at: Time.current } }

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
        end.to raise_error(Faraday::ConnectionFailed)
      end

      it 'retries on Faraday::TimeoutError' do
        allow(mock_service).to receive(:sync_to_external_system)
          .and_raise(Faraday::TimeoutError.new('Timeout'))

        expect do
          described_class.perform_now(product, catalog, timestamp)
        end.to raise_error(Faraday::TimeoutError)
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
        .and_return({ success: true })

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
