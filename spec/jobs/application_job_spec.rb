# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationJob, type: :job do
  describe "queue configuration" do
    it "uses test adapter in test environment" do
      expect(ActiveJob::Base.queue_adapter).to be_a(ActiveJob::QueueAdapters::TestAdapter)
    end
  end

  describe "queue helpers" do
    it "provides high_priority helper" do
      job_class = Class.new(ApplicationJob) do
        high_priority
      end

      # Queue name includes environment prefix in test
      expect(job_class.queue_name).to eq("test__high_priority")
    end

    it "provides default_priority helper" do
      job_class = Class.new(ApplicationJob) do
        default_priority
      end

      expect(job_class.queue_name).to eq("test__default")
    end

    it "provides low_priority helper" do
      job_class = Class.new(ApplicationJob) do
        low_priority
      end

      expect(job_class.queue_name).to eq("test__low_priority")
    end
  end

  describe "example jobs" do
    it "can enqueue high priority job" do
      expect {
        ExampleHighPriorityJob.perform_later("test")
      }.to have_enqueued_job(ExampleHighPriorityJob).on_queue("test__high_priority")
    end

    it "can enqueue default priority job" do
      expect {
        ExampleDefaultPriorityJob.perform_later("test")
      }.to have_enqueued_job(ExampleDefaultPriorityJob).on_queue("test__default")
    end

    it "can enqueue low priority job" do
      expect {
        ExampleLowPriorityJob.perform_later("test")
      }.to have_enqueued_job(ExampleLowPriorityJob).on_queue("test__low_priority")
    end
  end

  describe "job execution" do
    it "successfully performs a simple job" do
      job_class = Class.new(ApplicationJob) do
        def perform(value)
          value * 2
        end
      end

      result = job_class.perform_now(5)
      expect(result).to eq(10)
    end
  end

  describe "error handling" do
    it "re-raises errors after logging" do
      failing_job = Class.new(ApplicationJob) do
        def perform
          raise StandardError, "Test error"
        end
      end

      # Job should raise the error (after logging it)
      expect {
        failing_job.perform_now
      }.to raise_error(StandardError, "Test error")
    end

    it "logs error messages to Rails logger" do
      failing_job = Class.new(ApplicationJob) do
        def perform
          raise StandardError, "Test error"
        end
      end

      # Verify logs are written (at least one error log)
      allow(Rails.logger).to receive(:info)
      expect(Rails.logger).to receive(:error).at_least(:once)

      expect {
        failing_job.perform_now
      }.to raise_error(StandardError)
    end
  end
end
