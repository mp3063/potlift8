# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Product, type: :model do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product) { create(:product, company: company) }

  describe 'batch sync helper methods' do
    describe '#sync_to_all_catalogs_batch' do
      let!(:catalog1) { create(:catalog, company: company) }
      let!(:catalog2) { create(:catalog, company: company) }
      let!(:catalog_item1) { create(:catalog_item, product: product, catalog: catalog1) }
      let!(:catalog_item2) { create(:catalog_item, product: product, catalog: catalog2) }

      it 'enqueues batch sync jobs for all catalogs' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).with(queue: :low_priority).and_return(BatchProductSyncJob)

        expect(BatchProductSyncJob).to receive(:perform_later)
          .with([product.id], catalog1.id)
          .and_return(job_double)
        expect(BatchProductSyncJob).to receive(:perform_later)
          .with([product.id], catalog2.id)
          .and_return(job_double)

        product.sync_to_all_catalogs_batch
      end

      it 'returns array of jobs' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)
        jobs = product.sync_to_all_catalogs_batch
        expect(jobs).to be_an(Array)
        expect(jobs.size).to eq(2)
      end

      it 'uses low_priority queue by default' do
        job_double = double('job')
        expect(BatchProductSyncJob).to receive(:set).with(queue: :low_priority)
          .and_return(BatchProductSyncJob).at_least(:once)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

        product.sync_to_all_catalogs_batch
      end

      it 'allows custom queue' do
        job_double = double('job')
        expect(BatchProductSyncJob).to receive(:set).with(queue: :high_priority)
          .and_return(BatchProductSyncJob).at_least(:once)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

        product.sync_to_all_catalogs_batch(queue: :high_priority)
      end

      context 'when product not in any catalogs' do
        let(:orphan_product) { create(:product, company: company) }

        it 'returns empty array' do
          jobs = orphan_product.sync_to_all_catalogs_batch
          expect(jobs).to eq([])
        end
      end
    end

    describe '#sync_to_catalog' do
      it 'enqueues ProductSyncJob' do
        job_double = double('job')
        expect(ProductSyncJob).to receive(:perform_later)
          .with(product, catalog, kind_of(Time))
          .and_return(job_double)

        result = product.sync_to_catalog(catalog)
        expect(result).to be true
      end

      context 'with deduplication' do
        it 'checks for duplicate jobs' do
          job_double = double('job')
          expect(JobDeduplicator).to receive(:new)
            .with(
              job_name: 'ProductSyncJob',
              params: { product_id: product.id, catalog_id: catalog.id },
              window: 30
            )
            .and_return(double(unique?: true))
          allow(ProductSyncJob).to receive(:perform_later).and_return(job_double)

          product.sync_to_catalog(catalog)
        end

        context 'when job was recently executed' do
          before do
            allow_any_instance_of(JobDeduplicator).to receive(:unique?).and_return(false)
          end

          it 'skips enqueuing' do
            expect(ProductSyncJob).not_to receive(:perform_later)

            result = product.sync_to_catalog(catalog)
            expect(result).to be false
          end
        end

        context 'with force: true' do
          it 'bypasses deduplication' do
            job_double = double('job')
            expect(JobDeduplicator).not_to receive(:new)
            expect(ProductSyncJob).to receive(:perform_later).and_return(job_double)

            product.sync_to_catalog(catalog, force: true)
          end
        end
      end
    end

    describe '.batch_sync_to_catalog' do
      let(:products) { create_list(:product, 3, company: company) }
      let(:product_ids) { products.map(&:id) }

      it 'enqueues BatchProductSyncJob' do
        job_double = double('job')
        allow(BatchProductSyncJob).to receive(:set).with(queue: :low_priority).and_return(BatchProductSyncJob)
        expect(BatchProductSyncJob).to receive(:perform_later)
          .with(product_ids, catalog.id)
          .and_return(job_double)

        Product.batch_sync_to_catalog(product_ids, catalog.id)
      end

      it 'uses low_priority queue by default' do
        job_double = double('job')
        expect(BatchProductSyncJob).to receive(:set).with(queue: :low_priority)
          .and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

        Product.batch_sync_to_catalog(product_ids, catalog.id)
      end

      it 'allows custom queue' do
        job_double = double('job')
        expect(BatchProductSyncJob).to receive(:set).with(queue: :default)
          .and_return(BatchProductSyncJob)
        allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

        Product.batch_sync_to_catalog(product_ids, catalog.id, queue: :default)
      end
    end

    describe '.schedule_batch_sync' do
      let(:products) { create_list(:product, 3, company: company) }
      let(:product_ids) { products.map(&:id) }

      it 'schedules job for off-peak hour' do
        freeze_time do
          now = Time.current
          target_hour = 2
          target_time = now.change(hour: target_hour, min: 0, sec: 0)
          target_time += 1.day if target_time <= now

          wait_seconds = (target_time - now).to_i

          job_double = double('job')
          expect(BatchProductSyncJob).to receive(:set)
            .with(wait: wait_seconds, queue: :low_priority)
            .and_return(BatchProductSyncJob)
          allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

          Product.schedule_batch_sync(product_ids, catalog.id, off_peak_hour: target_hour)
        end
      end

      it 'logs scheduling info' do
        # The actual log message from the method
        expect(Rails.logger).to receive(:info).with(/Scheduling batch sync/).ordered
        # The log message from after_enqueue callback will also happen
        allow(Rails.logger).to receive(:info)

        Product.schedule_batch_sync(product_ids, catalog.id)
      end

      it 'allows custom off-peak hour' do
        freeze_time do
          now = Time.current
          target_hour = 3
          target_time = now.change(hour: target_hour, min: 0, sec: 0)
          target_time += 1.day if target_time <= now

          wait_seconds = (target_time - now).to_i

          job_double = double('job')
          expect(BatchProductSyncJob).to receive(:set)
            .with(wait: wait_seconds, queue: :low_priority)
            .and_return(BatchProductSyncJob)
          allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

          Product.schedule_batch_sync(product_ids, catalog.id, off_peak_hour: target_hour)
        end
      end

      context 'when target hour is later today' do
        it 'schedules for today' do
          now = Time.current.change(hour: 1, min: 0) # 1 AM
          target_hour = 2 # 2 AM (later today)

          travel_to(now) do
            target_time = now.change(hour: target_hour)
            wait_seconds = (target_time - now).to_i

            job_double = double('job')
            expect(BatchProductSyncJob).to receive(:set)
              .with(wait: wait_seconds, queue: :low_priority)
              .and_return(BatchProductSyncJob)
            allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

            Product.schedule_batch_sync(product_ids, catalog.id, off_peak_hour: target_hour)
          end
        end
      end

      context 'when target hour already passed today' do
        it 'schedules for tomorrow' do
          now = Time.current.change(hour: 3, min: 0) # 3 AM
          target_hour = 2 # 2 AM (passed, so tomorrow)

          travel_to(now) do
            target_time = now.change(hour: target_hour) + 1.day
            wait_seconds = (target_time - now).to_i

            job_double = double('job')
            expect(BatchProductSyncJob).to receive(:set)
              .with(wait: wait_seconds, queue: :low_priority)
              .and_return(BatchProductSyncJob)
            allow(BatchProductSyncJob).to receive(:perform_later).and_return(job_double)

            Product.schedule_batch_sync(product_ids, catalog.id, off_peak_hour: target_hour)
          end
        end
      end
    end
  end
end
