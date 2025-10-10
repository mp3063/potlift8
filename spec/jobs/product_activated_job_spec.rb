# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductActivatedJob, type: :job do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, product_status: :active) }
  let(:catalog) { create(:catalog, company: company) }
  let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

  describe 'queue configuration' do
    it 'is enqueued on the high_priority queue' do
      expect(ProductActivatedJob.new.queue_name).to eq('test__high_priority')
    end
  end

  describe '#perform' do

    it 'logs activation event' do
      allow(Rails.logger).to receive(:info).and_call_original
      expect(Rails.logger).to receive(:info).with(/Product activation job started/).and_call_original
      expect(Rails.logger).to receive(:info).with(/product_activated/).and_call_original
      expect(Rails.logger).to receive(:info).with(/Product activation job completed/).and_call_original

      described_class.perform_now(product)
    end

    context 'catalog synchronization' do
      it 'enqueues ProductSyncJob for each catalog' do
        expect do
          described_class.perform_now(product)
        end.to have_enqueued_job(ProductSyncJob)
          .with(product, catalog, kind_of(Time))
          .on_queue('test__default')
      end

      it 'skips catalogs with sync_paused flag' do
        catalog.update!(info: { 'sync_paused' => true })

        expect do
          described_class.perform_now(product)
        end.not_to have_enqueued_job(ProductSyncJob)
      end

      it 'handles product with no catalogs' do
        product.catalog_items.destroy_all

        expect do
          described_class.perform_now(product)
        end.not_to have_enqueued_job(ProductSyncJob)

        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/not in any catalogs/).and_call_original
        described_class.perform_now(product)
      end

      it 'syncs to multiple catalogs' do
        catalog2 = create(:catalog, company: company, code: 'CAT002')
        create(:catalog_item, catalog: catalog2, product: product)

        expect do
          described_class.perform_now(product)
        end.to have_enqueued_job(ProductSyncJob).exactly(2).times
      end

      it 'eager loads catalogs to prevent N+1 queries' do
        5.times do |i|
          cat = create(:catalog, company: company, code: "CAT#{i + 10}")
          create(:catalog_item, catalog: cat, product: product)
        end

        # Just verify it works without excessive queries
        # Count queries during execution
        query_count = 0
        counter = lambda do |_name, _start, _finish, _id, payload|
          query_count += 1 unless payload[:name] == 'SCHEMA'
        end

        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
          described_class.perform_now(product)
        end

        # Should use eager loading, not N+1 (reasonable limit for 6 catalogs)
        expect(query_count).to be < 30
      end
    end

    context 'superproduct notification' do
      let(:superproduct) do
        create(:product, company: company, product_type: :bundle, product_status: :active)
      end
      let!(:superproduct_catalog_item) do
        create(:catalog_item, catalog: catalog, product: superproduct)
      end
      let!(:product_configuration) do
        create(:product_configuration, superproduct: superproduct, subproduct: product)
      end

      it 'touches superproducts' do
        original_updated_at = superproduct.updated_at
        sleep 0.01

        described_class.perform_now(product)

        superproduct.reload
        expect(superproduct.updated_at).to be > original_updated_at
      end

      it 'enqueues delayed sync jobs for superproducts' do
        # Just verify that superproduct sync jobs are enqueued (at least 2: product + superproduct)
        expect do
          described_class.perform_now(product)
        end.to have_enqueued_job(ProductSyncJob).at_least(2).times

        # Verify that one of the jobs is delayed (check the enqueued jobs)
        delayed_jobs = enqueued_jobs.select { |j| j[:job] == ProductSyncJob && j[:at].present? }
        expect(delayed_jobs.size).to be >= 1
      end

      it 'handles product with no superproducts' do
        product.product_configurations_as_sub.destroy_all

        expect do
          described_class.perform_now(product)
        end.to have_enqueued_job(ProductSyncJob).exactly(1).times
      end

      it 'skips superproduct sync for paused catalogs' do
        catalog.update!(info: { 'sync_paused' => true })

        expect do
          described_class.perform_now(product)
        end.not_to have_enqueued_job(ProductSyncJob)
      end

      it 'logs superproduct notification' do
        allow(Rails.logger).to receive(:info).and_call_original
        expect(Rails.logger).to receive(:info).with(/Notifying .* superproduct/).and_call_original
        expect(Rails.logger).to receive(:info).with(/touched and sync jobs enqueued/).and_call_original

        described_class.perform_now(product)
      end

      context 'with multiple superproducts' do
        let(:superproduct2) do
          create(:product, company: company, product_type: :configurable,
                           configuration_type: :variant, product_status: :active)
        end
        let!(:superproduct2_catalog_item) do
          create(:catalog_item, catalog: catalog, product: superproduct2)
        end
        let!(:product_configuration2) do
          create(:product_configuration, superproduct: superproduct2, subproduct: product)
        end

        it 'touches all superproducts' do
          original_super1 = superproduct.updated_at
          original_super2 = superproduct2.updated_at
          sleep 0.01

          described_class.perform_now(product)

          superproduct.reload
          superproduct2.reload

          expect(superproduct.updated_at).to be > original_super1
          expect(superproduct2.updated_at).to be > original_super2
        end

        it 'enqueues sync jobs for all superproducts' do
          expect do
            described_class.perform_now(product)
          end.to have_enqueued_job(ProductSyncJob).at_least(3).times
        end
      end

      context 'with superproduct in multiple catalogs' do
        let(:catalog2) { create(:catalog, company: company, code: 'CAT003') }
        let!(:super_catalog_item2) do
          create(:catalog_item, catalog: catalog2, product: superproduct)
        end

        it 'syncs superproduct to all its catalogs' do
          expect do
            described_class.perform_now(product)
          end.to have_enqueued_job(ProductSyncJob)
            .with(superproduct, anything, anything)
            .at_least(2).times
        end
      end
    end

    context 'integration scenarios' do
      it 'handles complex product hierarchy' do
        # Create 3-level hierarchy - product needs to be a bundle to have subproducts
        bundle_product = create(:product, company: company, product_type: :bundle)
        create(:catalog_item, catalog: catalog, product: bundle_product)
        sub_sub = create(:product, company: company)
        create(:product_configuration, superproduct: bundle_product, subproduct: sub_sub)

        superproduct = create(:product, company: company, product_type: :configurable, configuration_type: :variant)
        create(:catalog_item, catalog: catalog, product: superproduct)
        create(:product_configuration, superproduct: superproduct, subproduct: product)

        expect do
          described_class.perform_now(bundle_product)
        end.to have_enqueued_job(ProductSyncJob).at_least(1).times
      end

      it 'handles activation with mixed catalog states' do
        active_catalog = catalog
        paused_catalog = create(:catalog, company: company, code: 'PAUSED',
                                          info: { 'sync_paused' => true })

        create(:catalog_item, catalog: paused_catalog, product: product)

        # Should only enqueue for active catalog, not paused
        expect do
          described_class.perform_now(product)
        end.to have_enqueued_job(ProductSyncJob)
          .with(product, active_catalog, kind_of(Time))

        # Verify no job was enqueued for paused catalog
        paused_jobs = enqueued_jobs.select do |j|
          j[:job] == ProductSyncJob &&
            j[:args][0] == product &&
            j[:args][1] == paused_catalog
        end
        expect(paused_jobs).to be_empty
      end
    end
  end

  describe 'job enqueueing' do
    it 'enqueues the job' do
      expect do
        described_class.perform_later(product)
      end.to have_enqueued_job(ProductActivatedJob)
        .with(product)
        .on_queue('test__high_priority')
    end
  end
end
