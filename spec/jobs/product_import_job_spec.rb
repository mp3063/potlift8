require 'rails_helper'

RSpec.describe ProductImportJob, type: :job do
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:file_content) do
    <<~CSV
      sku,name,description,active
      ABC123,Widget,A great widget,true
      DEF456,Gadget,An amazing gadget,true
    CSV
  end
  let(:job_id) { 'test-job-id-123' }
  let(:mock_redis) { instance_double(Redis) }

  before do
    # Mock Redis.new to return our mock
    allow(Redis).to receive(:new).and_return(mock_redis)
    allow(mock_redis).to receive(:setex).and_return('OK')
  end

  describe 'queue configuration' do
    it 'is enqueued on the default queue' do
      queue_name = ProductImportJob.new.queue_name
      # In test environment, queue names may be prefixed with 'test__'
      expect(queue_name).to match(/default$/)
    end
  end

  describe '#perform' do
    let(:progress_key) { "import_progress:#{job_id}" }

    before do
      # Mock job_id method to return predictable value
      allow_any_instance_of(ProductImportJob).to receive(:job_id).and_return(job_id)
    end

    context 'with successful import' do
      let(:import_result) do
        {
          imported_count: 2,
          updated_count: 0,
          errors: []
        }
      end

      before do
        mock_service = instance_double(ProductImportService, import!: import_result)
        allow(ProductImportService).to receive(:new).and_return(mock_service)
      end

      it 'calls ProductImportService with correct parameters' do
        expect(ProductImportService).to receive(:new).with(company, file_content, user)

        described_class.perform_now(company.id, file_content, user.id)
      end

      it 'sets initial progress in Redis' do
        expect(mock_redis).to receive(:setex).with(
          progress_key,
          3600,
          { status: 'processing', progress: 0 }.to_json
        )

        described_class.perform_now(company.id, file_content, user.id)
      end

      it 'updates progress to completed in Redis' do
        completed_data = {
          status: 'completed',
          progress: 100,
          imported_count: 2,
          updated_count: 0,
          errors: []
        }.to_json

        expect(mock_redis).to receive(:setex).with(
          progress_key,
          3600,
          completed_data
        )

        described_class.perform_now(company.id, file_content, user.id)
      end

      it 'logs import completion' do
        allow(Rails.logger).to receive(:info).and_call_original

        described_class.perform_now(company.id, file_content, user.id)

        expect(Rails.logger).to have_received(:info).with(/Product import completed/)
      end
    end

    context 'with import errors' do
      let(:import_result) do
        {
          imported_count: 1,
          updated_count: 0,
          errors: [
            { row: 2, error: 'SKU cannot be blank' }
          ]
        }
      end

      before do
        mock_service = instance_double(ProductImportService, import!: import_result)
        allow(ProductImportService).to receive(:new).and_return(mock_service)
      end

      it 'includes errors in completed progress' do
        completed_data = {
          status: 'completed',
          progress: 100,
          imported_count: 1,
          updated_count: 0,
          errors: [{ row: 2, error: 'SKU cannot be blank' }]
        }.to_json

        expect(mock_redis).to receive(:setex).with(
          progress_key,
          3600,
          completed_data
        )

        described_class.perform_now(company.id, file_content, user.id)
      end

      it 'still completes successfully' do
        expect {
          described_class.perform_now(company.id, file_content, user.id)
        }.not_to raise_error
      end
    end

    context 'when import fails' do
      let(:error_message) { 'Database connection error' }

      before do
        allow(ProductImportService).to receive(:new)
          .and_raise(StandardError.new(error_message))
      end

      it 'sets failed status in Redis' do
        failed_data = {
          status: 'failed',
          error: error_message
        }.to_json

        expect(mock_redis).to receive(:setex).with(
          progress_key,
          3600,
          failed_data
        )

        expect {
          described_class.perform_now(company.id, file_content, user.id)
        }.to raise_error(StandardError)
      end

      it 'logs error details' do
        allow(Rails.logger).to receive(:error).and_call_original

        expect {
          described_class.perform_now(company.id, file_content, user.id)
        }.to raise_error(StandardError)

        expect(Rails.logger).to have_received(:error).with(/Product import failed/)
      end

      it 're-raises the error for retry logic' do
        expect {
          described_class.perform_now(company.id, file_content, user.id)
        }.to raise_error(StandardError, error_message)
      end
    end

    context 'with missing company' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_now(999999, file_content, user.id)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with missing user' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.perform_now(company.id, file_content, 999999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with empty file content' do
      let(:empty_content) do
        <<~CSV
          sku,name,description,active
        CSV
      end

      let(:import_result) do
        {
          imported_count: 0,
          updated_count: 0,
          errors: []
        }
      end

      before do
        mock_service = instance_double(ProductImportService, import!: import_result)
        allow(ProductImportService).to receive(:new).and_return(mock_service)
      end

      it 'completes successfully with zero counts' do
        expect {
          described_class.perform_now(company.id, empty_content, user.id)
        }.not_to raise_error
      end

      it 'updates progress with zero counts' do
        completed_data = {
          status: 'completed',
          progress: 100,
          imported_count: 0,
          updated_count: 0,
          errors: []
        }.to_json

        expect(mock_redis).to receive(:setex).with(
          progress_key,
          3600,
          completed_data
        )

        described_class.perform_now(company.id, empty_content, user.id)
      end
    end

    context 'with malformed CSV' do
      let(:malformed_content) { "sku,name\n\"unclosed quote" }

      it 'handles CSV parsing errors gracefully' do
        # ProductImportService catches CSV::MalformedCSVError and returns a result
        # with errors rather than re-raising
        expect {
          described_class.perform_now(company.id, malformed_content, user.id)
        }.not_to raise_error
      end

      it 'updates Redis with completed status containing errors' do
        setex_calls = []
        allow(mock_redis).to receive(:setex) do |key, ttl, json|
          setex_calls << { key: key, ttl: ttl, json: json }
          'OK'
        end

        described_class.perform_now(company.id, malformed_content, user.id)

        # Last call should be completed with errors from the service
        last_call = setex_calls.last
        data = JSON.parse(last_call[:json])
        expect(data['status']).to eq('completed')
        expect(data['errors']).to be_present
      end
    end
  end

  describe 'progress tracking' do
    let(:progress_key) { "import_progress:#{job_id}" }

    before do
      allow_any_instance_of(ProductImportJob).to receive(:job_id).and_return(job_id)
    end

    it 'uses 1 hour TTL for progress data' do
      mock_service = instance_double(ProductImportService, import!: { imported_count: 0, updated_count: 0, errors: [] })
      allow(ProductImportService).to receive(:new).and_return(mock_service)

      expect(mock_redis).to receive(:setex).with(progress_key, 3600, anything).at_least(:once)

      described_class.perform_now(company.id, file_content, user.id)
    end

    it 'stores progress as JSON' do
      mock_service = instance_double(ProductImportService, import!: { imported_count: 2, updated_count: 0, errors: [] })
      allow(ProductImportService).to receive(:new).and_return(mock_service)

      expect(mock_redis).to receive(:setex).with(progress_key, 3600, kind_of(String)).at_least(:once) do |_key, _ttl, json|
        expect { JSON.parse(json) }.not_to raise_error
      end

      described_class.perform_now(company.id, file_content, user.id)
    end
  end

  describe 'job enqueueing' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(company.id, file_content, user.id)
      }.to have_enqueued_job(ProductImportJob)
        .with(company.id, file_content, user.id)
    end

    it 'can be scheduled for later execution' do
      freeze_time do
        expect {
          described_class.set(wait: 10.minutes).perform_later(company.id, file_content, user.id)
        }.to have_enqueued_job(ProductImportJob)
          .with(company.id, file_content, user.id)
          .at(10.minutes.from_now)
      end
    end
  end

  describe 'integration with ProductImportService' do
    it 'passes correct parameters to service' do
      expect(ProductImportService).to receive(:new).with(company, file_content, user).and_call_original

      allow_any_instance_of(ProductImportService).to receive(:import!)
        .and_return({ imported_count: 2, updated_count: 0, errors: [] })

      described_class.perform_now(company.id, file_content, user.id)
    end

    it 'calls import! on the service' do
      mock_service = instance_double(ProductImportService)
      allow(ProductImportService).to receive(:new).and_return(mock_service)

      expect(mock_service).to receive(:import!).and_return({
        imported_count: 2,
        updated_count: 0,
        errors: []
      })

      described_class.perform_now(company.id, file_content, user.id)
    end
  end

  describe 'error handling with retries' do
    before do
      allow_any_instance_of(ProductImportJob).to receive(:job_id).and_return(job_id)
    end

    context 'with transient errors' do
      it 'allows retry on connection errors' do
        allow(ProductImportService).to receive(:new)
          .and_raise(ActiveRecord::ConnectionNotEstablished)

        expect {
          described_class.perform_now(company.id, file_content, user.id)
        }.to raise_error(ActiveRecord::ConnectionNotEstablished)
      end

      it 'allows retry on timeout errors' do
        allow(ProductImportService).to receive(:new)
          .and_raise(Timeout::Error)

        expect {
          described_class.perform_now(company.id, file_content, user.id)
        }.to raise_error(Timeout::Error)
      end
    end
  end

  describe 'batch import performance' do
    let(:large_csv) do
      header = "sku,name,description,active\n"
      rows = (1..250).map { |i| "SKU#{i},Product #{i},Description #{i},true" }.join("\n")
      header + rows
    end

    before do
      allow_any_instance_of(ProductImportJob).to receive(:job_id).and_return(job_id)
    end

    it 'handles large imports without timeout' do
      mock_service = instance_double(ProductImportService)
      allow(ProductImportService).to receive(:new).and_return(mock_service)
      allow(mock_service).to receive(:import!).and_return({
        imported_count: 250,
        updated_count: 0,
        errors: []
      })

      expect {
        described_class.perform_now(company.id, large_csv, user.id)
      }.not_to raise_error
    end

    it 'passes large CSV to service' do
      mock_service = instance_double(ProductImportService)
      expect(ProductImportService).to receive(:new)
        .with(company, large_csv, user)
        .and_return(mock_service)

      allow(mock_service).to receive(:import!).and_return({
        imported_count: 250,
        updated_count: 0,
        errors: []
      })

      described_class.perform_now(company.id, large_csv, user.id)
    end
  end
end
