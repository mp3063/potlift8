# frozen_string_literal: true

# Retry a transient Chrome/Selenium race during system specs.
#
# Under load, Chrome (149+) with selenium-webdriver occasionally reports a
# detached-DOM-node condition — when a Turbo Frame/Stream replaces an element
# mid-query — as:
#
#   Selenium::WebDriver::Error::UnknownError:
#     unknown error: unhandled inspector error:
#     {"code":-32000,"message":"Node with given id does not belong to the document"}
#
# Capybara already retries the equivalent StaleElementReferenceError (and even
# adds chromedriver race errors like InvalidSelectorError to its retry set), but
# this newer variant arrives as a generic UnknownError, which Capybara does not
# recognize as retryable — so it propagates and flakes DOM-heavy workflow specs.
#
# We extend Capybara's own retry predicate (Capybara::Node::Base#catch_error?)
# to treat ONLY this specific message as retryable. Everything else defers to
# super, so unrelated UnknownErrors are unaffected, and Capybara's existing wait
# timer still bounds the retry — a genuinely persistent error surfaces after the
# timeout with its original message intact (not masked).
module CapybaraTransientNodeRetry
  TRANSIENT_NODE_MESSAGE = /node with given id does not belong to the document|unhandled inspector error/i

  def catch_error?(error, errors = nil)
    if error.is_a?(::Selenium::WebDriver::Error::UnknownError) &&
       error.message&.match?(TRANSIENT_NODE_MESSAGE)
      return true
    end

    super
  end
end

Capybara::Node::Base.prepend(CapybaraTransientNodeRetry)
