# frozen_string_literal: true

# Progress of the latest "Sync All" run on a catalog. An item counts as done
# once Shopify8 has answered for it (confirmed or failed) since the run began.
# A run is frozen at its first finish (finished_at), so later item changes
# can't reopen it.
class Catalog::SyncRunProgress
  STALL_AFTER = 10.minutes
  SHOW_FINISHED_FOR = 5.minutes

  attr_reader :total, :confirmed, :failed, :started_at, :handed_off_at, :last_activity_at, :finished_at

  def initialize(total:, confirmed:, failed:, started_at:, handed_off_at:, last_activity_at:, finished_at: nil)
    @total = total
    @confirmed = confirmed
    @failed = failed
    @started_at = started_at
    @handed_off_at = handed_off_at
    @last_activity_at = last_activity_at
    @finished_at = finished_at
  end

  def waiting
    [ total - confirmed - failed, 0 ].max
  end

  def handed_off?
    handed_off_at.present?
  end

  def finished?
    finished_at.present? || waiting.zero?
  end

  # When the last answer came in; nil while running
  def finish_time
    finished_at || (last_activity_at if finished?)
  end

  def stalled?
    !finished? && last_activity_at < STALL_AFTER.ago
  end

  def visible?
    !finished? || finish_time >= SHOW_FINISHED_FOR.ago
  end

  # Seconds since the run started; frozen at the last answer once finished
  def elapsed
    ((finish_time || Time.current) - started_at).to_i
  end
end
