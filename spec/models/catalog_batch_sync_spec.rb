# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Catalog, type: :model do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }

  describe 'batch sync helper methods' do
    describe '#batch_sync_all_products' do
      let!(:products) { create_list(:product, 5, company: company) }
      let!(:catalog_items) do
        products.map { |p| create(:catalog_item, product: p, catalog: catalog) }
      end

      it 'enqueues batch sync job for all products' do
        product_ids = products.map(&:id)

        # Mock the chain: BatchProductSyncJob.set(queue: :low_priority).perform_later(...)
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).with(queue: :low_priority).and_return(BatchProductSyncJob)
        expect(BatchProductSyncJob).to receive(:perform_later)
          .with(match_array(product_ids), catalog.id)
          .and_return(job_double)

        catalog.batch_sync_all_products
      end

      it 'returns array with single job by default' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)
        jobs = catalog.batch_sync_all_products
        expect(jobs).to be_an(Array)
        expect(jobs.size).to eq(1)
      end

      it 'uses low_priority queue' do
        job_double = double('job')
        expect(BatchProductSyncJob).to receive(:set).with(queue: :low_priority)
          .and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

        catalog.batch_sync_all_products
      end

      context 'with batch_size specified' do
        let!(:products) { create_list(:product, 150, company: company) }
        let!(:catalog_items) do
          products.map { |p| create(:catalog_item, product: p, catalog: catalog) }
        end

        it 'splits into multiple batches' do
          job_double = double('job')
          allow(BatchProductSyncJob).to receive(:set).with(queue: :low_priority).and_return(BatchProductSyncJob)
          expect(BatchProductSyncJob).to receive(:perform_later)
            .exactly(3).times # 150 / 50 = 3 batches
            .and_return(job_double)

          catalog.batch_sync_all_products(batch_size: 50)
        end

        it 'returns array of jobs' do
          job_double = double('job')
          allow(BatchProductSyncJob).to receive(:set).and_return(BatchProductSyncJob)
          allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)
          jobs = catalog.batch_sync_all_products(batch_size: 50)
          expect(jobs.size).to eq(3)
        end
      end

      context 'when catalog has no products' do
        let(:empty_catalog) { create(:catalog, company: company) }

        it 'returns empty array' do
          jobs = empty_catalog.batch_sync_all_products
          expect(jobs).to eq([])
        end

        it 'logs message' do
          expect(Rails.logger).to receive(:info).with(/No products to sync/)
          empty_catalog.batch_sync_all_products
        end
      end
    end

    describe '#batch_sync_active_products' do
      let!(:active_products) { create_list(:product, 3, company: company, product_status: :active) }
      let!(:inactive_products) { create_list(:product, 2, company: company, product_status: :disabled) }
      let!(:catalog_items) do
        (active_products + inactive_products).map do |p|
          state = p.product_status == 'active' ? :active : :inactive
          create(:catalog_item, product: p, catalog: catalog, catalog_item_state: state)
        end
      end

      it 'enqueues batch sync only for active products' do
        active_product_ids = active_products.map(&:id)

        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).with(queue: :low_priority).and_return(BatchProductSyncJob)
        expect(BatchProductSyncJob).to receive(:perform_later) do |product_ids, catalog_id|
          expect(product_ids).to match_array(active_product_ids)
          expect(catalog_id).to eq(catalog.id)
          job_double
        end

        catalog.batch_sync_active_products
      end

      it 'returns single job' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)
        job = catalog.batch_sync_active_products
        expect(job).not_to be_nil
      end

      context 'when no active products' do
        let(:catalog_without_active) { create(:catalog, company: company) }

        it 'returns nil' do
          job = catalog_without_active.batch_sync_active_products
          expect(job).to be_nil
        end

        it 'logs message' do
          expect(Rails.logger).to receive(:info).with(/No active products/)
          catalog_without_active.batch_sync_active_products
        end
      end
    end

    describe '#schedule_full_sync' do
      let!(:products) { create_list(:product, 1000, company: company) }
      let!(:catalog_items) do
        products.map { |p| create(:catalog_item, product: p, catalog: catalog) }
      end

      it 'schedules multiple batches' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).and_return(BatchProductSyncJob)
        expect(BatchProductSyncJob).to receive(:perform_later)
          .exactly(2).times # 1000 / 500 = 2 batches
          .and_return(job_double)

        catalog.schedule_full_sync(batch_size: 500)
      end

      it 'staggers batches by 5 minutes' do
        freeze_time do
          now = Time.current
          target_time = now.change(hour: 2, min: 0, sec: 0)
          target_time += 1.day if target_time <= now

          base_wait = (target_time - now).to_i

          job_double = double('job')

          # First batch at base wait time
          expect(BatchProductSyncJob).to receive(:set)
            .with(wait: base_wait, queue: :low_priority)
            .and_return(BatchProductSyncJob)
            .ordered

          expect(BatchProductSyncJob).to receive(:perform_later).and_return(job_double).ordered

          # Second batch 5 minutes later
          expect(BatchProductSyncJob).to receive(:set)
            .with(wait: base_wait + 5.minutes, queue: :low_priority)
            .and_return(BatchProductSyncJob)
            .ordered

          expect(BatchProductSyncJob).to receive(:perform_later).and_return(job_double).ordered

          catalog.schedule_full_sync(batch_size: 500)
        end
      end

      it 'returns array of scheduled jobs' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)
        jobs = catalog.schedule_full_sync(batch_size: 500)
        expect(jobs.size).to eq(2)
      end

      it 'logs scheduling info' do
        # The actual log message from the method
        expect(Rails.logger).to receive(:info).with(/Scheduling sync of 1000 products/).ordered
        # The log message from after_enqueue callback will also happen
        allow(Rails.logger).to receive(:info)

        catalog.schedule_full_sync(batch_size: 500)
      end

      context 'when catalog has no products' do
        let(:empty_catalog) { create(:catalog, company: company) }

        it 'returns empty array' do
          jobs = empty_catalog.schedule_full_sync
          expect(jobs).to eq([])
        end
      end
    end

    describe '#rate_limit_config' do
      context 'with default configuration' do
        it 'returns default values' do
          config = catalog.rate_limit_config
          expect(config).to eq({ limit: 100, period: 60 })
        end
      end

      context 'with custom configuration' do
        before do
          catalog.update!(info: {
            'rate_limit' => {
              'limit' => 200,
              'period' => 120
            }
          })
        end

        it 'returns custom values' do
          config = catalog.rate_limit_config
          expect(config).to eq({ limit: 200, period: 120 })
        end
      end
    end

    describe '#update_rate_limit' do
      it 'updates rate limit configuration' do
        catalog.update_rate_limit(limit: 150, period: 90)

        expect(catalog.info['rate_limit']['limit']).to eq(150)
        expect(catalog.info['rate_limit']['period']).to eq(90)
      end

      it 'persists the changes' do
        catalog.update_rate_limit(limit: 150, period: 90)
        catalog.reload

        expect(catalog.info['rate_limit']['limit']).to eq(150)
        expect(catalog.info['rate_limit']['period']).to eq(90)
      end

      it 'includes timestamp' do
        freeze_time do
          catalog.update_rate_limit(limit: 150, period: 90)
          expect(catalog.info['rate_limit']['updated_at']).to eq(Time.current.iso8601)
        end
      end

      it 'logs update' do
        expect(Rails.logger).to receive(:info)
          .with(/Updated rate limit for catalog #{catalog.code}/)

        catalog.update_rate_limit(limit: 150, period: 90)
      end
    end
  end
end
