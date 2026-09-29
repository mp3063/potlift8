# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sync All progress', type: :system, js: true do
  let(:company) { create(:company, code: "TEST#{SecureRandom.hex(4).upcase}", name: 'Test Company') }
  let(:current_user) { create(:user, company: company, name: 'Test User') }
  let(:catalog) { create(:catalog, :shop_connected, company: company, code: 'WEB-EUR') }
  let!(:items) do
    3.times.map { |i| create(:catalog_item, catalog: catalog, product: create(:product, company: company, sku: "SYNC#{i}")) }
  end

  def sign_in_user
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
    # The cable connection authenticates from the session, which these stubs
    # bypass. Broadcasts then reach the browser: the test cable adapter
    # subclasses the in-process async one, and Capybara's server runs here.
    allow_any_instance_of(ApplicationCable::Connection).to receive(:find_verified_user).and_return(current_user.id)
  end

  before do
    sign_in_user
    allow_any_instance_of(ProductSyncService).to receive(:sync_to_external_system)
      .and_return(double(success?: true, error: nil))
  end

  # As Shopify8's callback does (SyncTaskProcessor#update_sync_status_from_callback)
  def confirm(item)
    item.reload.update!(sync_status: :synced, last_synced_at: Time.current, last_sync_error: nil)
  end

  def reject(item)
    item.reload.update!(sync_status: :failed, last_sync_error: 'Shopify said no')
  end

  it 'shows live progress from Sync All until Shopify has answered for every product' do
    visit catalog_items_path(catalog)
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    accept_confirm { click_button 'Sync All' }

    within "#sync_progress_#{catalog.id}" do
      expect(page).to have_text('Syncing WEB-EUR to Shopify')
      expect(page).to have_text('Sending to Shopify8')
      expect(page).to have_text('0 of 3 confirmed · 0 failed · 3 waiting')
    end

    BatchProductSyncJob.perform_now(items.map(&:product_id), catalog.id)
    expect(page).to have_css("#sync_progress_#{catalog.id}", text: 'Sent to Shopify8')

    confirm(items[0])
    reject(items[1])
    expect(page).to have_css("#sync_progress_#{catalog.id}", text: '1 of 3 confirmed · 1 failed · 1 waiting')
    expect(page).to have_css("[role='progressbar'][aria-valuenow='2'][aria-valuemax='3']")

    confirm(items[2])
    within "#sync_progress_#{catalog.id}" do
      expect(page).to have_text('2 synced, 1 failed')
      expect(page).to have_link('Show failed')
    end

    click_link 'Show failed'
    expect(page).to have_text('SYNC1')
    expect(page).to have_no_text('SYNC0')
    expect(page).to have_no_text('SYNC2')
  end

  it 'survives a reload and can be dismissed once finished' do
    visit catalog_items_path(catalog)
    accept_confirm { click_button 'Sync All' }
    expect(page).to have_text('0 of 3 confirmed')

    items.each { |item| confirm(item) }
    refresh

    expect(page).to have_css("#sync_progress_#{catalog.id}", text: /All 3 products synced in \d+:\d\d/)
    click_button 'Dismiss sync progress'

    expect(page).to have_no_css("#sync_progress_#{catalog.id}")
    expect(catalog.reload.info).not_to have_key('sync_run')
  end
end
