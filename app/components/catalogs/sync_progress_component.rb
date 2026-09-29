# frozen_string_literal: true

module Catalogs
  # Live progress of a catalog's "Sync All" run, shown inside the sync summary
  # card. Re-rendered on every Shopify8 answer through the card's broadcast.
  class SyncProgressComponent < ViewComponent::Base
    attr_reader :progress, :catalog

    def initialize(progress:, catalog:)
      @progress = progress
      @catalog = catalog
    end

    def state
      @state ||= if progress.finished?
        progress.failed.zero? ? :succeeded : :finished_with_failures
      elsif progress.stalled?
        :stalled
      else
        :running
      end
    end

    def running?
      state == :running
    end

    def dismissible?
      !running?
    end

    def panel_classes
      case state
      when :succeeded then "border-green-200 bg-green-50"
      when :running then "border-gray-200 bg-gray-50"
      else "border-amber-200 bg-amber-50"
      end
    end

    def text_classes
      case state
      when :succeeded then "text-green-800"
      when :running then "text-gray-700"
      else "text-amber-800"
      end
    end

    def heading
      case state
      when :succeeded
        "All #{pluralize(progress.total, 'product')} synced in #{format_elapsed(progress.elapsed)}"
      when :finished_with_failures
        "#{progress.confirmed} synced, #{progress.failed} failed"
      else
        "Syncing #{catalog.code} to Shopify"
      end
    end

    def status_line
      if state == :stalled
        "Still waiting for Shopify — #{pluralize(progress.waiting, 'product')} " \
          "#{progress.waiting == 1 ? 'has' : 'have'} no answer yet"
      else
        "#{progress.confirmed} of #{progress.total} confirmed · #{progress.failed} failed · #{progress.waiting} waiting"
      end
    end

    def answered
      progress.confirmed + progress.failed
    end

    def confirmed_width
      percent(progress.confirmed)
    end

    def failed_width
      percent(progress.failed)
    end

    def format_elapsed(seconds)
      format("%d:%02d", seconds / 60, seconds % 60)
    end

    private

    def percent(count)
      return "0%" if progress.total.zero?

      "#{(count * 100.0 / progress.total).round(1)}%"
    end

    def pluralize(count, word)
      helpers.pluralize(count, word)
    end
  end
end
