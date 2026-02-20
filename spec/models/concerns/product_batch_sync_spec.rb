# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductBatchSync do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:catalog) { create(:catalog, company: company) }

  before do
    product.catalog_items.create!(catalog: catalog)
  end

  describe "#sync_to_all_catalogs_batch" do
    it "enqueues batch sync jobs for all catalogs" do
      expect {
        product.sync_to_all_catalogs_batch
      }.to have_enqueued_job(BatchProductSyncJob)
    end

    it "returns empty array when no catalogs" do
      product.catalog_items.destroy_all

      result = product.sync_to_all_catalogs_batch

      expect(result).to eq([])
    end
  end

  describe "#sync_to_catalog" do
    it "enqueues ProductSyncJob" do
      expect {
        product.sync_to_catalog(catalog)
      }.to have_enqueued_job(ProductSyncJob)
    end
  end

  describe ".batch_sync_to_catalog" do
    it "enqueues BatchProductSyncJob with product ids" do
      expect {
        Product.batch_sync_to_catalog([ product.id ], catalog.id)
      }.to have_enqueued_job(BatchProductSyncJob)
    end
  end
end
