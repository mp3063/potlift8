# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncBroadcastable, type: :model do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product) { create(:product, company: company) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product, sync_status: :never_synced) }

  describe 'after_update_commit callback' do
    it 'broadcasts when sync_status changes' do
      expect(catalog_item).to receive(:broadcast_replace_to).twice

      catalog_item.update!(sync_status: :synced, last_synced_at: Time.current)
    end

    it 'does not broadcast when sync_status does not change' do
      catalog_item.update!(sync_status: :synced, last_synced_at: Time.current)

      expect(catalog_item).not_to receive(:broadcast_replace_to)

      catalog_item.update!(last_synced_at: Time.current)
    end

    it 'broadcasts to the catalog sync_status stream' do
      expect(catalog_item).to receive(:broadcast_replace_to).with(
        catalog, "sync_status",
        target: "catalog_item_#{catalog_item.id}_sync",
        partial: "catalogs/catalog_item_sync_cell",
        locals: { catalog_item: catalog_item }
      )
      expect(catalog_item).to receive(:broadcast_replace_to).with(
        catalog, "sync_status",
        target: "sync_summary_#{catalog.id}",
        partial: "catalogs/sync_summary_card",
        locals: hash_including(catalog: catalog, sync_counts: a_hash_including(:synced, :outdated, :failed, :never))
      )

      catalog_item.update!(sync_status: :pending)
    end
  end

  describe '#compute_sync_counts' do
    before do
      # Create a mix of sync statuses
      create(:catalog_item, catalog: catalog, product: create(:product, company: company),
             sync_status: :synced, last_synced_at: 30.minutes.ago)
      create(:catalog_item, catalog: catalog, product: create(:product, company: company),
             sync_status: :synced, last_synced_at: 2.hours.ago)
      create(:catalog_item, catalog: catalog, product: create(:product, company: company),
             sync_status: :failed)
      create(:catalog_item, catalog: catalog, product: create(:product, company: company),
             sync_status: :never_synced)
    end

    it 'returns correct counts for each status' do
      counts = catalog_item.send(:compute_sync_counts)

      expect(counts[:synced]).to eq(1)    # synced within 1 hour
      expect(counts[:outdated]).to eq(1)  # synced more than 1 hour ago
      expect(counts[:failed]).to eq(1)
      expect(counts[:never]).to eq(2)     # catalog_item + the never_synced one
    end
  end
end
