# API Sync Tasks Controller
#
# RESTful API endpoints for receiving sync tasks from external systems.
# Processes bidirectional synchronization of product data, inventory, and orders.
#
# Authentication:
# - Requires Bearer token authentication (see Api::V1::BaseController)
# - All queries are scoped to @current_company (multi-tenant)
#
# Endpoints:
# - POST /api/v1/sync_tasks - Receive and process sync task
#
# @example Product update sync
#   POST /api/v1/sync_tasks
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "sync_task": {
#       "origin_event_id": "evt_m23_12345",
#       "direction": "inbound",
#       "event_type": "product_update",
#       "key": "ABC123",
#       "load": {
#         "sku": "ABC123",
#         "name": "Updated Product Name",
#         "product_status": "active"
#       }
#     }
#   }
#
#   Response (Success):
#   {
#     "success": true,
#     "event_id": "evt_m23_12345",
#     "event_type": "product_update",
#     "processed_at": "2025-10-11T12:00:00Z",
#     "result": {
#       "product_id": 123,
#       "sku": "ABC123",
#       "updated": true
#     }
#   }
#
# @example Inventory update sync
#   POST /api/v1/sync_tasks
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "sync_task": {
#       "origin_event_id": "evt_shopify_67890",
#       "direction": "inbound",
#       "event_type": "inventory_update",
#       "key": "ABC123",
#       "load": {
#         "sku": "ABC123",
#         "updates": [
#           { "storage_code": "MAIN", "value": 150 }
#         ]
#       }
#     }
#   }
#
#   Response (Success):
#   {
#     "success": true,
#     "event_id": "evt_shopify_67890",
#     "event_type": "inventory_update",
#     "processed_at": "2025-10-11T12:00:00Z",
#     "result": {
#       "product_id": 123,
#       "sku": "ABC123",
#       "inventory": {
#         "available": 150,
#         "incoming": 0,
#         "eta": null
#       }
#     }
#   }
#
# @example Duplicate event (idempotent)
#   POST /api/v1/sync_tasks
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "sync_task": {
#       "origin_event_id": "evt_m23_12345",
#       "direction": "inbound",
#       "event_type": "product_update",
#       "load": { ... }
#     }
#   }
#
#   Response (Duplicate):
#   {
#     "success": true,
#     "event_id": "evt_m23_12345",
#     "event_type": "product_update",
#     "duplicate": true,
#     "message": "Event already processed (idempotent)"
#   }
#
module Api
  module V1
    class SyncTasksController < Api::V1::BaseController
      # POST /api/v1/sync_tasks
      #
      # Receive and process a sync task from external system.
      # Supports idempotent processing using origin_event_id.
      #
      # Required Parameters:
      # - sync_task[origin_event_id]: Unique event identifier from source system
      # - sync_task[direction]: Sync direction ('inbound' or 'outbound')
      # - sync_task[event_type]: Type of event (product_update, inventory_update, etc.)
      # - sync_task[load]: Payload data for the event
      #
      # Optional Parameters:
      # - sync_task[key]: Primary key for the entity (e.g., SKU, order ID)
      #
      # @return [JSON] Processing result with success status
      #
      def create
        # Extract parameters
        sync_task_params = params.require(:sync_task)

        origin_event_id = sync_task_params[:origin_event_id]
        direction = sync_task_params[:direction]
        event_type = sync_task_params[:event_type]
        load = sync_task_params[:load]
        key = sync_task_params[:key]

        # Validate required parameters
        if origin_event_id.blank?
          return render_error(
            "origin_event_id is required",
            status: :bad_request,
            error_code: "missing_parameter"
          )
        end

        if direction.blank?
          return render_error(
            "direction is required",
            status: :bad_request,
            error_code: "missing_parameter"
          )
        end

        if event_type.blank?
          return render_error(
            "event_type is required",
            status: :bad_request,
            error_code: "missing_parameter"
          )
        end

        if load.blank?
          return render_error(
            "load is required",
            status: :bad_request,
            error_code: "missing_parameter"
          )
        end

        # Process sync task using service
        processor = SyncTaskProcessor.new(@current_company)
        result = processor.process(
          origin_event_id: origin_event_id,
          direction: direction,
          event_type: event_type,
          load: load,
          key: key
        )

        # Return result
        if result[:success]
          render_success(result)
        else
          # Return service error directly with proper structure
          render json: {
            success: false,
            error: result[:error] || "Failed to process sync task",
            event_id: origin_event_id,
            event_type: event_type
          }, status: :unprocessable_entity
        end
      end

      private

      # Strong parameters for sync task
      #
      # Note: We don't use strong parameters here because load can have dynamic structure
      # Instead, we validate at the service layer
      #
      def sync_task_params
        params.require(:sync_task).permit(
          :origin_event_id,
          :direction,
          :event_type,
          :key,
          load: {}
        )
      end
    end
  end
end
