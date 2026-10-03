# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncBroadcastable, type: :model do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product) { create(:product, company: company) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product, sync_status: :never_synced) }

  describe 'after_update_commit callback' do
    it 'broadcasts the row and the summary card when sync_status changes' do
      expect(catalog_item).to receive(:broadcast_replace_to).twice
      expect(catalog).to receive(:broadcast_sync_summary).once

      catalog_item.update!(sync_status: :synced, last_synced_at: Time.current)
    end

    it 'does not broadcast when sync_status does not change' do
      catalog_item.update!(sync_status: :synced, last_synced_at: Time.current)

      expect(catalog_item).not_to receive(:broadcast_replace_to)
      expect(catalog).not_to receive(:broadcast_sync_summary)

      catalog_item.update!(last_synced_at: Time.current)
    end

    it 'broadcasts to the catalog and product sync_status streams' do
      expect(catalog_item).to receive(:broadcast_replace_to).with(
        catalog, "sync_status",
        target: "catalog_item_#{catalog_item.id}_sync",
        partial: "catalogs/catalog_item_sync_cell",
        locals: { catalog_item: catalog_item }
      )
      expect(catalog_item).to receive(:broadcast_replace_to).with(
        product, "sync_status",
        target: "catalog_item_#{catalog_item.id}_sync",
        partial: "catalogs/catalog_item_sync_cell",
        locals: { catalog_item: catalog_item }
      )
      expect(catalog).to receive(:broadcast_replace_to).with(
        catalog, "sync_status",
        target: "sync_summary_#{catalog.id}",
        partial: "catalogs/sync_summary_card",
        locals: { catalog: catalog, sync_counts: a_hash_including(:synced, :outdated, :pending, :failed, :never) },
        attributes: { method: :morph }
      )

      catalog_item.update!(sync_status: :pending)
    end
  end

  describe 'summary card broadcast' do
    it 'renders the card with the pending count' do
      create(:catalog_item, catalog: catalog, product: create(:product, company: company), sync_status: :pending)
      rendered = nil
      allow(catalog).to receive(:broadcast_replace_to) do |*_args, partial:, locals:, **|
        rendered = ApplicationController.render(partial: partial, locals: locals)
      end

      catalog_item.update!(sync_status: :pending)

      expect(rendered).to include("sync_summary_#{catalog.id}")
      expect(rendered).to match(%r{>2</div>\s*<div class="text-xs text-gray-500">Pending})
    end
  end
end
