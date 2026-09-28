# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductRemovalJob, type: :job do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, :shop_connected, company: company) }
  let(:service) { instance_double(ProductSyncService) }

  it 'removes the sku from the catalog shop' do
    allow(ProductSyncService).to receive(:new).with(nil, catalog).and_return(service)
    expect(service).to receive(:remove_from_external_system).with('GONE-1')
      .and_return(SyncLockable::SyncLockResult.new(success: true))

    described_class.perform_now('GONE-1', catalog.id)
  end

  it 'raises when the removal fails so the job is retried' do
    allow(ProductSyncService).to receive(:new).and_return(service)
    allow(service).to receive(:remove_from_external_system)
      .and_return(SyncLockable::SyncLockResult.new(success: false, error: 'API error: 500'))

    expect { described_class.perform_now('GONE-1', catalog.id) }.to raise_error(/API error: 500/)
  end

  it 'does nothing when the catalog is not connected to a shop' do
    catalog.update!(info: {})
    expect(ProductSyncService).not_to receive(:new)

    described_class.perform_now('GONE-1', catalog.id)
  end

  it 'does nothing when the catalog no longer exists' do
    expect(ProductSyncService).not_to receive(:new)

    described_class.perform_now('GONE-1', -1)
  end
end
