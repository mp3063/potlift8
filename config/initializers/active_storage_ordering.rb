# frozen_string_literal: true

# ActiveStorage Attachment Ordering Fix
#
# By default, ActiveStorage's has_many_attached doesn't include ORDER BY in queries,
# which can lead to non-deterministic ordering depending on PostgreSQL's query planner.
#
# This patches ActiveStorage::Attached::Many to always order attachments by ID,
# ensuring consistent ordering based on creation time (attachment ID = creation order).
#
# Implemented via Module#prepend rather than reopening the class with `def`, so it
# layers on top of ActiveStorage's method instead of redefining it (which emits a
# "method redefined; discarding old attachments" warning under -w).
module ActiveStorageOrderedAttachments
  def attachments
    if change.present?
      change.attachments
    else
      record.public_send("#{name}_attachments").order(id: :asc)
    end
  end
end

Rails.application.config.to_prepare do
  unless ActiveStorage::Attached::Many.include?(ActiveStorageOrderedAttachments)
    ActiveStorage::Attached::Many.prepend(ActiveStorageOrderedAttachments)
  end
end
