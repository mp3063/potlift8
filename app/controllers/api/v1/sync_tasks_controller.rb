module Api
  module V1
    class SyncTasksController < Api::V1::BaseController
      def create
        sync_task_params = params.require(:sync_task)

        origin_event_id = sync_task_params[:origin_event_id]
        direction = sync_task_params[:direction]
        event_type = sync_task_params[:event_type]
        load = sync_task_params[:load]
        key = sync_task_params[:key]

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

        processor = SyncTaskProcessor.new(@current_company)
        result = processor.process(
          origin_event_id: origin_event_id,
          direction: direction,
          event_type: event_type,
          load: load,
          key: key
        )

        if result[:success]
          render_success(result)
        else
          render json: {
            success: false,
            error: result[:error] || "Failed to process sync task",
            event_id: origin_event_id,
            event_type: event_type
          }, status: :unprocessable_entity
        end
      end

      private

      # Note: We don't use strong parameters here because load can have dynamic structure
      # Instead, we validate at the service layer
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
