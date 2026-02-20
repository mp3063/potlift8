# frozen_string_literal: true

# SyncErrorSanitizer
#
# Sanitizes sync error messages before storing them on catalog_items.
# Prevents leaking internal details (URLs, stack traces, DB errors)
# via Turbo Stream broadcasts to the browser.
#
module SyncErrorSanitizer
  extend ActiveSupport::Concern

  private

  def sanitize_sync_error(error)
    message = error.is_a?(Exception) ? error.message : error.to_s

    case message
    when /timeout/i, /timed?\s*out/i
      "Sync timed out. Will retry automatically."
    when /rate.?limit/i, /throttl/i, /429/
      "Shopify rate limit reached. Will retry shortly."
    when /not.?found/i, /404/
      "Resource not found in Shopify."
    when /unauthorized/i, /forbidden/i, /401/, /403/
      "Authentication error. Check Shopify credentials."
    when /connection.?refused/i, /connect/i, /ECONNREFUSED/i
      "Could not connect to sync service."
    when /JSON/i, /parse/i, /malformed/i
      "Invalid response from Shopify."
    else
      "Sync failed (ref: #{SecureRandom.hex(4)})"
    end.truncate(255)
  end
end
