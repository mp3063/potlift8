require 'rails_helper'

RSpec.describe ProductImportJob, type: :job do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:file_content) do
    <<~CSV
      sku,name,description,active
      ABC123,Widget,A great widget,true
      DEF456,Gadget,An amazing gadget,true
    CSV
  end

  let(:import) do
    i = company.imports.create!(user: user, import_type: "products", status: "pending")
    i.file.attach(
      io: StringIO.new(file_content),
      filename: "products.csv",
      content_type: "text/csv"
    )
    i
  end

  describe 'queue configuration' do
    it 'is enqueued on the default queue' do
      expect(ProductImportJob.new.queue_name).to match(/default$/)
    end
  end

  describe '#perform' do
    context 'with successful import' do
      let(:import_result) do
        { imported_count: 2, updated_count: 0, errors: [] }
      end

      before do
        mock_service = instance_double(ProductImportService, import!: import_result)
        allow(ProductImportService).to receive(:new).and_return(mock_service)
      end

      it 'calls ProductImportService with downloaded file content' do
        expect(ProductImportService).to receive(:new).with(
          company,
          a_string_including("ABC123,Widget"),
          user,
          on_progress: kind_of(Proc)
        )

        described_class.perform_now(import.id)
      end

      it 'sets import status to processing then completed' do
        described_class.perform_now(import.id)

        import.reload
        expect(import.status).to eq("completed")
        expect(import.progress).to eq(100)
        expect(import.imported_count).to eq(2)
        expect(import.updated_count).to eq(0)
        expect(import.total_rows).to eq(2)
        expect(import.started_at).to be_present
        expect(import.completed_at).to be_present
      end

      it 'logs a short completion message (no CSV content)' do
        allow(Rails.logger).to receive(:info).and_call_original
        described_class.perform_now(import.id)

        expect(Rails.logger).to have_received(:info).with(
          a_string_matching(/Product import completed: import_id=#{import.id}/)
        )
      end
    end

    context 'with row-level errors' do
      let(:import_result) do
        {
          imported_count: 1,
          updated_count: 0,
          errors: [ { row: 2, error: "SKU cannot be blank" } ]
        }
      end

      before do
        mock_service = instance_double(ProductImportService, import!: import_result)
        allow(ProductImportService).to receive(:new).and_return(mock_service)
      end

      it 'stores row errors as stringified JSONB on the import' do
        described_class.perform_now(import.id)

        import.reload
        expect(import.status).to eq("completed")
        expect(import.row_errors).to eq([ { "row" => 2, "error" => "SKU cannot be blank" } ])
        expect(import.failed_count).to eq(1)
      end
    end

    context 'when service raises' do
      before do
        allow(ProductImportService).to receive(:new)
          .and_raise(StandardError.new("database connection error"))
      end

      it 'marks the import as failed with the error message and re-raises' do
        expect {
          described_class.perform_now(import.id)
        }.to raise_error(StandardError, "database connection error")

        import.reload
        expect(import.status).to eq("failed")
        expect(import.error_message).to eq("database connection error")
      end
    end

    context 'with missing import record' do
      it 'raises (and is discarded by ApplicationJob)' do
        expect {
          described_class.perform_now(999_999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with progress callback' do
      it 'passes a progress callback that persists intermediate progress to the import' do
        progress_values = []
        progress_callback = nil

        fake_service = instance_double(ProductImportService)
        allow(ProductImportService).to receive(:new) do |*_args, on_progress:|
          progress_callback = on_progress
          fake_service
        end
        allow(fake_service).to receive(:import!) do
          # Simulate the service invoking the progress callback mid-run
          progress_callback.call(50, 100)
          progress_values << import.reload.progress
          { imported_count: 2, updated_count: 0, errors: [] }
        end

        described_class.perform_now(import.id)

        expect(progress_values).to eq([ 50 ])
        expect(import.reload.progress).to eq(100) # final terminal update
      end
    end
  end

  describe 'job enqueueing' do
    it 'enqueues the job with only the import id as argument' do
      expect {
        described_class.perform_later(import.id)
      }.to have_enqueued_job(ProductImportJob).with(import.id)
    end
  end
end
