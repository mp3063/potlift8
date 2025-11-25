# frozen_string_literal: true

# ActiveStorage Attachment Ordering Fix
#
# By default, ActiveStorage's has_many_attached doesn't include ORDER BY in queries,
# which can lead to non-deterministic ordering depending on PostgreSQL's query planner.
#
# This initializer patches ActiveStorage::Attached::Many to always order attachments by ID,
# ensuring consistent ordering based on creation time (attachment ID = creation order).

Rails.application.config.to_prepare do
  ActiveStorage::Attached::Many.class_eval do
    # Override attachments method to return ordered results
    def attachments
      if change.present?
        change.attachments
      else
        # Get the underlying association and add ordering
        record.public_send("#{name}_attachments").order(id: :asc)
      end
    end
  end
end
