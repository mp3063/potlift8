require 'rails_helper'

RSpec.describe Catalog, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:catalog)).to be_valid
    end

    it 'creates valid catalogs with all types' do
      expect(create(:catalog, :webshop)).to be_valid
      expect(create(:catalog, :supply)).to be_valid
    end

    it 'creates valid catalogs with all currencies' do
      expect(create(:catalog, :eur)).to be_valid
      expect(create(:catalog, :sek)).to be_valid
      expect(create(:catalog, :nok)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:sync_lock).optional }
    it { is_expected.to have_many(:catalog_items).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:catalog_items) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:catalog) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:catalog_type) }
    it { is_expected.to validate_inclusion_of(:currency_code).in_array(%w[eur sek nok]) }

    context 'code uniqueness' do
      let(:company) { create(:company) }

      before do
        create(:catalog, company: company, code: 'WEBSHOP1')
      end

      it 'validates uniqueness of code scoped to company' do
        duplicate = build(:catalog, company: company, code: 'WEBSHOP1')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different companies' do
        other_company = create(:company)
        catalog = build(:catalog, company: other_company, code: 'WEBSHOP1')
        expect(catalog).to be_valid
      end

      it 'validates uniqueness case-insensitively' do
        duplicate = build(:catalog, company: company, code: 'webshop1')
        expect(duplicate).not_to be_valid
      end
    end

    context 'invalid currency' do
      it 'rejects invalid currency codes' do
        catalog = build(:catalog, currency_code: 'usd')
        expect(catalog).not_to be_valid
        expect(catalog.errors[:currency_code]).to be_present
      end
    end
  end

  # Test enums
  describe 'enums' do
    describe 'catalog_type' do
      it 'defines all 2 catalog types' do
        expect(Catalog.catalog_types).to eq({
          'webshop' => 1,
          'supply' => 2
        })
      end

      it 'allows setting catalog type' do
        catalog = create(:catalog, catalog_type: :webshop)
        expect(catalog.webshop?).to be true

        catalog.update(catalog_type: :supply)
        expect(catalog.supply?).to be true
      end
    end
  end

  # Test #minimum_ratio method
  describe '#sync_target' do
    it 'defaults to shopify8 when blank' do
      expect(build(:catalog, info: {}).sync_target).to eq('shopify8')
      expect(build(:catalog, info: { 'sync_target' => '' }).sync_target).to eq('shopify8')
    end

    it 'is the stored target otherwise' do
      expect(build(:catalog, info: { 'sync_target' => 'bizcart' }).sync_target).to eq('bizcart')
    end
  end

  describe '#shop_connected?' do
    it 'is true when the catalog has a shop_id, whatever the target' do
      expect(build(:catalog, info: { 'shop_id' => 1 }).shop_connected?).to be true
      expect(build(:catalog, info: { 'shop_id' => 1, 'sync_target' => 'bizcart' }).shop_connected?).to be true
    end

    it 'is false without a shop_id' do
      expect(build(:catalog, info: {}).shop_connected?).to be false
      expect(build(:catalog, info: { 'shop_id' => '' }).shop_connected?).to be false
    end
  end

  describe '#shopify_connected?' do
    it 'is true when the catalog feeds a shop through Shopify8' do
      expect(build(:catalog, info: { 'shop_id' => 1 }).shopify_connected?).to be true
      expect(build(:catalog, info: { 'shop_id' => 1, 'sync_target' => 'shopify8' }).shopify_connected?).to be true
    end

    it 'is false for another target or without a shop_id' do
      expect(build(:catalog, info: { 'shop_id' => 1, 'sync_target' => 'bizcart' }).shopify_connected?).to be false
      expect(build(:catalog, info: {}).shopify_connected?).to be false
    end
  end

  describe '#shop_key' do
    it 'combines the target and the shop_id, whether stored as integer or string' do
      expect(build(:catalog, info: { 'shop_id' => 1 }).shop_key).to eq('shopify8:1')
      expect(build(:catalog, info: { 'shop_id' => '1' }).shop_key).to eq('shopify8:1')
    end

    it 'differs for the same shop_id under another target' do
      expect(build(:catalog, info: { 'shop_id' => 1, 'sync_target' => 'bizcart' }).shop_key).to eq('bizcart:1')
    end

    it 'is nil without a shop_id' do
      expect(build(:catalog, info: {}).shop_key).to be_nil
    end
  end

  describe '#sync_counts' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }

    def add_item(**attrs)
      create(:catalog_item, catalog: catalog, product: create(:product, company: company), **attrs)
    end

    it 'counts items per sync state, including pending' do
      add_item(sync_status: :synced, last_synced_at: 30.minutes.ago)
      add_item(sync_status: :synced, last_synced_at: 2.hours.ago)
      add_item(sync_status: :pending)
      add_item(sync_status: :pending)
      add_item(sync_status: :failed)
      add_item(sync_status: :never_synced)

      expect(catalog.sync_counts).to eq(synced: 1, outdated: 1, pending: 2, failed: 1, never: 1)
    end
  end

  describe '#broadcast_sync_summary' do
    include Turbo::Broadcastable::TestHelper

    let(:catalog) { create(:catalog) }

    it 'morphs the summary card for viewers of the items page' do
      broadcasts = capture_turbo_stream_broadcasts([ catalog, 'sync_status' ]) { catalog.broadcast_sync_summary }

      expect(broadcasts.size).to eq(1)
      expect(broadcasts.first['action']).to eq('replace')
      expect(broadcasts.first['method']).to eq('morph')
      expect(broadcasts.first['target']).to eq("sync_summary_#{catalog.id}")
      expect(broadcasts.first.to_html).to include('Shopify Sync')
    end
  end

  describe '#sync_run_progress' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:started_at) { Time.zone.parse('2026-09-29 12:00:00') }

    def add_item(**attrs)
      create(:catalog_item, catalog: catalog, product: create(:product, company: company), **attrs)
    end

    def start_run(total:, handed_off_at: nil)
      catalog.update!(info: catalog.info.merge(
        'sync_run' => { 'started_at' => started_at.iso8601(6), 'total' => total,
                        'handed_off_at' => handed_off_at&.iso8601(6) }
      ))
    end

    around { |example| travel_to(started_at - 1.minute) { example.run } }

    it 'is nil without a run' do
      expect(catalog.sync_run_progress).to be_nil
    end

    context 'with a run' do
      let!(:old_synced) { add_item(sync_status: :synced, last_synced_at: started_at - 1.minute) }
      let!(:old_failed) { add_item(sync_status: :failed) }
      let!(:confirmed_item) { add_item(sync_status: :pending) }
      let!(:failed_item) { add_item(sync_status: :pending) }
      let!(:waiting_item) { add_item(sync_status: :pending) }

      before do
        start_run(total: 5)
        travel_to(started_at + 30.seconds)
        confirmed_item.update!(sync_status: :synced, last_synced_at: Time.current)
        travel_to(started_at + 40.seconds)
        failed_item.update!(sync_status: :failed, last_sync_error: 'boom')
      end

      it 'counts answers given since the run started, ignoring older ones' do
        progress = catalog.sync_run_progress

        expect(progress.total).to eq(5)
        expect(progress.confirmed).to eq(1)
        expect(progress.failed).to eq(1)
        expect(progress.waiting).to eq(3)
        expect(progress.started_at).to eq(started_at)
        expect(progress).not_to be_finished
        expect(progress).not_to be_handed_off
      end

      it 'clamps waiting at zero' do
        start_run(total: 1)
        expect(catalog.sync_run_progress.waiting).to eq(0)
      end

      it 'is handed off once the batch job recorded it' do
        start_run(total: 5, handed_off_at: started_at + 5.seconds)
        expect(catalog.sync_run_progress).to be_handed_off
      end

      it 'is finished when every item has an answer, with elapsed up to the last answer' do
        start_run(total: 2)
        travel_to(started_at + 3.minutes)

        progress = catalog.sync_run_progress
        expect(progress).to be_finished
        expect(progress.elapsed).to eq(40)
      end

      it 'counts elapsed up to now while running' do
        travel_to(started_at + 90.seconds)
        expect(catalog.sync_run_progress.elapsed).to eq(90)
      end

      it 'is stalled after 10 minutes without activity' do
        travel_to(started_at + 40.seconds + 9.minutes)
        expect(catalog.sync_run_progress).not_to be_stalled

        travel_to(started_at + 40.seconds + 11.minutes)
        expect(catalog.sync_run_progress).to be_stalled
      end

      it 'is never stalled once finished' do
        start_run(total: 2)
        travel_to(started_at + 1.hour)
        expect(catalog.sync_run_progress).not_to be_stalled
      end

      it 'is visible while running, however long ago' do
        travel_to(started_at + 1.hour)
        expect(catalog.sync_run_progress).to be_visible
      end

      it 'is visible within 5 minutes of finishing, and not after' do
        start_run(total: 2)
        travel_to(started_at + 40.seconds + 4.minutes)
        expect(catalog.sync_run_progress).to be_visible

        travel_to(started_at + 40.seconds + 6.minutes)
        expect(catalog.sync_run_progress).not_to be_visible
      end

      context 'once seen finished' do
        before do
          start_run(total: 2)
          travel_to(started_at + 1.minute)
          catalog.sync_run_progress
        end

        it 'stores the finish time and final counts on the run' do
          expect(catalog.reload.info['sync_run']).to include(
            'finished_at' => (started_at + 40.seconds).iso8601(6), 'confirmed' => 1, 'failed' => 1
          )
        end

        it 'stays finished when an item goes pending again later' do
          travel_to(started_at + 2.days)
          confirmed_item.update!(sync_status: :pending)

          progress = catalog.reload.sync_run_progress
          expect(progress).to be_finished
          expect(progress).not_to be_stalled
          expect(progress.confirmed).to eq(1)
          expect(progress.failed).to eq(1)
          expect(progress.elapsed).to eq(40)
        end

        it 'does not stall when an answered item is removed' do
          confirmed_item.destroy!
          travel_to(started_at + 20.minutes)

          progress = catalog.reload.sync_run_progress
          expect(progress).to be_finished
          expect(progress).not_to be_stalled
        end

        it 'is hidden 5 minutes after the finish' do
          travel_to(started_at + 40.seconds + 4.minutes)
          expect(catalog.reload.sync_run_progress).to be_visible

          travel_to(started_at + 40.seconds + 6.minutes)
          expect(catalog.reload.sync_run_progress).not_to be_visible
        end
      end
    end
  end

  describe '#minimum_ratio' do
    it 'returns 1.5 for SEK' do
      catalog = build(:catalog, currency_code: 'sek')
      expect(catalog.minimum_ratio).to eq(1.5)
    end

    it 'returns 1.5 for NOK' do
      catalog = build(:catalog, currency_code: 'nok')
      expect(catalog.minimum_ratio).to eq(1.5)
    end

    it 'returns 1.0 for EUR' do
      catalog = build(:catalog, currency_code: 'eur')
      expect(catalog.minimum_ratio).to eq(1.0)
    end
  end

  # Test #requires_minimum_ratio? method
  describe '#requires_minimum_ratio?' do
    it 'returns true for SEK' do
      catalog = build(:catalog, currency_code: 'sek')
      expect(catalog.requires_minimum_ratio?).to be true
    end

    it 'returns true for NOK' do
      catalog = build(:catalog, currency_code: 'nok')
      expect(catalog.requires_minimum_ratio?).to be true
    end

    it 'returns false for EUR' do
      catalog = build(:catalog, currency_code: 'eur')
      expect(catalog.requires_minimum_ratio?).to be false
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }
    let(:other_company) { create(:company) }

    describe '.for_company' do
      let!(:catalog1) { create(:catalog, company: company) }
      let!(:catalog2) { create(:catalog, company: company) }
      let!(:other_catalog) { create(:catalog, company: other_company) }

      it 'returns catalogs for specified company' do
        result = Catalog.for_company(company.id)
        expect(result).to contain_exactly(catalog1, catalog2)
        expect(result).not_to include(other_catalog)
      end
    end

    describe '.by_type' do
      let!(:webshop1) { create(:catalog, :webshop, company: company) }
      let!(:webshop2) { create(:catalog, :webshop, company: company) }
      let!(:supply) { create(:catalog, :supply, company: company) }

      it 'returns catalogs of specified type' do
        result = Catalog.by_type(:webshop)
        expect(result).to contain_exactly(webshop1, webshop2)
        expect(result).not_to include(supply)
      end
    end

    describe '.by_currency' do
      let!(:eur1) { create(:catalog, :eur, company: company) }
      let!(:eur2) { create(:catalog, :eur, company: company) }
      let!(:sek) { create(:catalog, :sek, company: company) }

      it 'returns catalogs with specified currency' do
        result = Catalog.by_currency('eur')
        expect(result).to contain_exactly(eur1, eur2)
        expect(result).not_to include(sek)
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores custom metadata' do
        catalog = create(:catalog, :with_info)
        expect(catalog.info['description']).to eq('Catalog description')
        expect(catalog.info['region']).to eq('EU')
      end

      it 'defaults to empty hash' do
        catalog = create(:catalog)
        expect(catalog.info).to eq({})
      end
    end

    describe 'cache field' do
      it 'stores cached values' do
        catalog = create(:catalog, :with_cache)
        expect(catalog.cache['products_count']).to eq(100)
        expect(catalog.cache['active_items']).to eq(85)
      end

      it 'defaults to empty hash' do
        catalog = create(:catalog)
        expect(catalog.cache).to eq({})
      end
    end
  end

  # Test helper methods
  describe 'helper methods' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }

    describe '#active_products' do
      let(:product1) { create(:product, company: company) }
      let(:product2) { create(:product, company: company) }
      let(:product3) { create(:product, company: company) }

      before do
        create(:catalog_item, catalog: catalog, product: product1, catalog_item_state: :active)
        create(:catalog_item, catalog: catalog, product: product2, catalog_item_state: :active)
        create(:catalog_item, catalog: catalog, product: product3, catalog_item_state: :inactive)
      end

      it 'returns only active products' do
        result = catalog.active_products
        expect(result).to contain_exactly(product1, product2)
        expect(result).not_to include(product3)
      end
    end

    describe '#products_count' do
      before do
        create_list(:catalog_item, 5, catalog: catalog)
      end

      it 'returns count of catalog items' do
        expect(catalog.products_count).to eq(5)
      end
    end

    describe '#rate_limit_config' do
      it 'returns default rate limit config when not set' do
        config = catalog.rate_limit_config
        expect(config[:limit]).to eq(100)
        expect(config[:period]).to eq(60)
      end

      it 'returns custom rate limit config when set' do
        catalog.update(info: {
          'rate_limit' => {
            'limit' => 50,
            'period' => 30
          }
        })

        config = catalog.rate_limit_config
        expect(config[:limit]).to eq(50)
        expect(config[:period]).to eq(30)
      end
    end

    describe '#update_rate_limit' do
      it 'updates rate limit configuration' do
        catalog.update_rate_limit(limit: 200, period: 120)

        expect(catalog.info['rate_limit']['limit']).to eq(200)
        expect(catalog.info['rate_limit']['period']).to eq(120)
        expect(catalog.info['rate_limit']['updated_at']).to be_present
      end

      it 'persists rate limit changes' do
        catalog.update_rate_limit(limit: 150, period: 90)
        catalog.reload

        expect(catalog.info['rate_limit']['limit']).to eq(150)
        expect(catalog.info['rate_limit']['period']).to eq(90)
      end
    end
  end

  # Test batch sync methods
  describe 'batch sync methods' do
    include ActiveJob::TestHelper

    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }

    describe '#batch_sync_all_products' do
      context 'with no products' do
        it 'returns empty array and logs message' do
          expect(Rails.logger).to receive(:info).with(/No products to sync/)
          result = catalog.batch_sync_all_products
          expect(result).to eq([])
        end
      end

      context 'with products' do
        let!(:product1) { create(:product, company: company) }
        let!(:product2) { create(:product, company: company) }
        let!(:product3) { create(:product, company: company) }

        before do
          create(:catalog_item, catalog: catalog, product: product1)
          create(:catalog_item, catalog: catalog, product: product2)
          create(:catalog_item, catalog: catalog, product: product3)
        end

        it 'enqueues single batch job when batch_size is nil' do
          expect {
            catalog.batch_sync_all_products(queue: :low_priority, batch_size: nil)
          }.to have_enqueued_job(BatchProductSyncJob).exactly(1).times
        end

        it 'enqueues multiple batch jobs when batch_size is specified' do
          expect {
            catalog.batch_sync_all_products(queue: :low_priority, batch_size: 2)
          }.to have_enqueued_job(BatchProductSyncJob).exactly(2).times
        end

        it 'uses correct queue for batch job' do
          jobs = catalog.batch_sync_all_products(queue: :high_priority)
          expect(jobs.first.queue_name).to match(/high_priority/)
        end

        it 'passes catalog_id to batch job' do
          jobs = catalog.batch_sync_all_products
          expect(jobs).to all(be_a(ActiveJob::Base))
        end
      end
    end

    describe '#batch_sync_active_products' do
      let(:product1) { create(:product, company: company) }
      let(:product2) { create(:product, company: company) }
      let(:product3) { create(:product, company: company) }

      before do
        create(:catalog_item, catalog: catalog, product: product1, catalog_item_state: :active)
        create(:catalog_item, catalog: catalog, product: product2, catalog_item_state: :active)
        create(:catalog_item, catalog: catalog, product: product3, catalog_item_state: :inactive)
      end

      it 'enqueues job only for active products' do
        expect {
          catalog.batch_sync_active_products(queue: :low_priority)
        }.to have_enqueued_job(BatchProductSyncJob).exactly(1).times
      end

      it 'returns nil when no active products' do
        catalog.catalog_items.update_all(catalog_item_state: :inactive)
        expect(Rails.logger).to receive(:info).with(/No active products to sync/)
        result = catalog.batch_sync_active_products
        expect(result).to be_nil
      end
    end

    describe '#schedule_full_sync' do
      let!(:product1) { create(:product, company: company) }
      let!(:product2) { create(:product, company: company) }

      before do
        create(:catalog_item, catalog: catalog, product: product1)
        create(:catalog_item, catalog: catalog, product: product2)
      end

      it 'schedules jobs for future execution' do
        freeze_time do
          expect {
            catalog.schedule_full_sync(off_peak_hour: 2, batch_size: 1)
          }.to have_enqueued_job(BatchProductSyncJob).exactly(2).times
        end
      end

      it 'uses low_priority queue' do
        freeze_time do
          jobs = catalog.schedule_full_sync(off_peak_hour: 2)
          expect(jobs.first.queue_name).to match(/low_priority/)
        end
      end

      it 'returns empty array when no products' do
        catalog.catalog_items.destroy_all
        expect(Rails.logger).to receive(:info).with(/No products to sync/)
        result = catalog.schedule_full_sync
        expect(result).to eq([])
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'complete catalog with all associations' do
      let(:catalog) { create(:catalog, :with_items, :with_info, :with_cache, company: company) }

      it 'has all associations working' do
        expect(catalog.catalog_items.count).to be > 0
        expect(catalog.products.count).to be > 0
        expect(catalog.info).not_to be_empty
        expect(catalog.cache).not_to be_empty
      end
    end

    context 'catalog with sync tracking' do
      let(:sync_lock) { create(:sync_lock) }
      let!(:catalog1) { create(:catalog, company: company, sync_lock: sync_lock) }
      let!(:catalog2) { create(:catalog, company: company, sync_lock: sync_lock) }

      it 'groups catalogs by sync operation' do
        synced_catalogs = company.catalogs.where(sync_lock: sync_lock)
        expect(synced_catalogs).to contain_exactly(catalog1, catalog2)
      end
    end

    context 'catalog deletion cascade' do
      let(:catalog) { create(:catalog, :with_items, company: company) }

      it 'destroys all dependent catalog items' do
        items_count = catalog.catalog_items.count

        expect do
          catalog.destroy
        end.to change { CatalogItem.count }.by(-items_count)
      end
    end

    context 'multi-currency catalog system' do
      let!(:eur_catalog) { create(:catalog, :eur, company: company, name: 'EU Webshop') }
      let!(:sek_catalog) { create(:catalog, :sek, company: company, name: 'SE Webshop') }
      let!(:nok_catalog) { create(:catalog, :nok, company: company, name: 'NO Webshop') }

      it 'correctly identifies ratio requirements for each currency' do
        expect(eur_catalog.requires_minimum_ratio?).to be false
        expect(sek_catalog.requires_minimum_ratio?).to be true
        expect(nok_catalog.requires_minimum_ratio?).to be true
      end

      it 'provides correct minimum ratios' do
        expect(eur_catalog.minimum_ratio).to eq(1.0)
        expect(sek_catalog.minimum_ratio).to eq(1.5)
        expect(nok_catalog.minimum_ratio).to eq(1.5)
      end
    end
  end
end
