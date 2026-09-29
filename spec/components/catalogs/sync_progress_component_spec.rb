# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalogs::SyncProgressComponent, type: :component do
  let(:catalog) { build_stubbed(:catalog, code: "WEB-EUR") }
  let(:now) { Time.zone.parse("2026-09-29 12:00:00") }

  around { |example| travel_to(now) { example.run } }

  def progress(confirmed:, failed:, total: 61, handed_off: true, started_ago: 42.seconds, last_activity_ago: 0.seconds)
    Catalog::SyncRunProgress.new(
      total: total, confirmed: confirmed, failed: failed,
      started_at: now - started_ago,
      handed_off_at: handed_off ? now - started_ago + 5.seconds : nil,
      last_activity_at: now - last_activity_ago
    )
  end

  def render_progress(progress)
    render_inline(described_class.new(progress: progress, catalog: catalog))
  end

  context "when running before hand-off" do
    before { render_progress(progress(confirmed: 0, failed: 0, handed_off: false)) }

    it "shows both steps in progress" do
      expect(page).to have_text("Syncing WEB-EUR to Shopify")
      expect(page).to have_text("Sending to Shopify8")
      expect(page).not_to have_text("Sent to Shopify8")
      expect(page).to have_text("Confirming in Shopify…")
      expect(page).to have_css(".animate-pulse", count: 2)
    end

    it "shows the counts and a ticking elapsed time" do
      expect(page).to have_css("[aria-live='polite']", text: "0 of 61 confirmed · 0 failed · 61 waiting")
      expect(page).to have_css("[data-controller='elapsed-time'][data-elapsed-time-seconds-value='42']", text: "0:42")
    end

    it "animates the waiting part of the bar" do
      expect(page).to have_css("[role='progressbar'].animate-progress-stripes")
    end
  end

  context "when running after hand-off" do
    before { render_progress(progress(confirmed: 38, failed: 2)) }

    it "checks off the first step" do
      expect(page).to have_css("li", text: "Sent to Shopify8") { |li| li.has_css?("svg.text-green-600") }
      expect(page).not_to have_text("Sending to Shopify8")
      expect(page).to have_css(".animate-pulse", count: 1)
    end

    it "exposes progress to assistive tech" do
      bar = page.find("[role='progressbar']")
      expect(bar["aria-valuenow"]).to eq("40")
      expect(bar["aria-valuemin"]).to eq("0")
      expect(bar["aria-valuemax"]).to eq("61")
      expect(page).to have_css("[aria-live='polite']", text: "38 of 61 confirmed · 2 failed · 21 waiting")
    end

    it "sizes the segments by share of the total" do
      expect(page.find("[data-segment='confirmed']")["style"]).to eq("width: 62.3%")
      expect(page.find("[data-segment='failed']")["style"]).to eq("width: 3.3%")
    end

    it "offers no dismiss button while running" do
      expect(page).not_to have_button("Dismiss sync progress")
    end
  end

  context "when all confirmed" do
    before { render_progress(progress(confirmed: 61, failed: 0, started_ago: 72.seconds)) }

    it "shows a green success panel with the total time" do
      expect(page).to have_css(".bg-green-50", text: "All 61 products synced in 1:12")
      expect(page).not_to have_css("[data-controller='elapsed-time']")
      expect(page).not_to have_css(".animate-pulse")
      expect(page).not_to have_css(".animate-progress-stripes")
    end

    it "can be dismissed" do
      expect(page).to have_css("form[action='/catalogs/WEB-EUR/sync_run'] input[name='_method'][value='delete']", visible: :all)
      expect(page).to have_button("Dismiss sync progress")
    end
  end

  context "when some failed" do
    before { render_progress(progress(confirmed: 59, failed: 2)) }

    it "shows an amber panel with a link to the failed items" do
      expect(page).to have_css(".bg-amber-50", text: "59 synced, 2 failed")
      expect(page).to have_link("Show failed", href: "/catalogs/WEB-EUR/items?sync_status=failed")
      expect(page).to have_button("Dismiss sync progress")
    end
  end

  context "when stalled" do
    before { render_progress(progress(confirmed: 38, failed: 2, started_ago: 20.minutes, last_activity_ago: 11.minutes)) }

    it "says what is still missing, without a spinner" do
      expect(page).to have_css(".bg-amber-50", text: "Still waiting for Shopify — 21 products have no answer yet")
      expect(page).not_to have_css(".animate-pulse")
      expect(page).not_to have_css(".animate-progress-stripes")
      expect(page).to have_button("Dismiss sync progress")
    end
  end
end
