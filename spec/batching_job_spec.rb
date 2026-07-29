# frozen_string_literal: true

require "sidekiq/testing"

RSpec.describe Simplekiq::BatchingJob do
  before do
    Sidekiq::Testing.inline!
  end

  describe "batching" do
    let(:test_job) do
      Class.new do
        include Simplekiq::BatchingJob

        def perform_batching(arg)
          queue_batch(arg)
        end

        def perform_batch(arg)
          Output.call(arg)
        end
      end
    end

    it "runs batches" do
      stub_const("TestJob", test_job)
      stub_const("Output", output = double("Output", call: nil))

      test_job.new.perform("test")

      expect(output).to have_received(:call).with("test")
    end

    it "queues a job with a readable name" do
      stub_const("TestJob", test_job)
      allow(TestJob::SimplekiqBatch).to receive(:perform_async)

      test_job.new.perform("test")

      expect(TestJob::SimplekiqBatch).to have_received(:perform_async)
    end
  end

  describe "on_success" do
    let(:test_job) do
      Class.new do
        include Simplekiq::BatchingJob

        def perform_batching(things)
          things.each { |t| queue_batch(t) }
        end

        def perform_batch(arg)
        end

        def on_success(_, options)
          Output.call(options["args"].first)
        end
      end
    end

    it "runs the on_success callback even if no batches are run", sidekiq: :fake do
      stub_const("TestJob", test_job)
      stub_const("Output", output = double("Output", call: nil))
      stub_batches

      test_job.new.perform([])
      run_all_jobs_and_batches

      expect(output).to have_received(:call).with([])
    end

    it "runs the on_success callback when batches complete successfully", sidekiq: :fake do
      stub_const("TestJob", test_job)
      stub_const("Output", output = double("Output", call: nil))
      stub_batches

      test_job.new.perform(["test"])
      run_all_jobs_and_batches

      expect(output).to have_received(:call).with(["test"])
    end
  end

  describe "on_complete" do
    let(:test_job) do
      Class.new do
        include Simplekiq::BatchingJob

        def perform_batching(things)
          things.each { |t| queue_batch(t) }
        end

        def perform_batch(arg)
        end

        def on_complete(_, options)
          Output.call(options["args"].first)
        end
      end
    end

    it "runs the on_complete callback even if no batches are run", sidekiq: :fake do
      stub_const("TestJob", test_job)
      stub_const("Output", output = double("Output", call: nil))
      stub_batches

      test_job.new.perform([])
      run_all_jobs_and_batches

      expect(output).to have_received(:call).with([])
    end

    it "runs the on_complete callback when each job has been run once", sidekiq: :fake do
      stub_const("TestJob", test_job)
      stub_const("Output", output = double("Output", call: nil))
      stub_batches

      test_job.new.perform(["test"])
      run_all_jobs_and_batches

      expect(output).to have_received(:call).with(["test"])
    end
  end

  describe "on_death" do
    let(:test_job) do
      Class.new do
        include Simplekiq::BatchingJob

        def perform_batching(things)
          things.each { |t| queue_batch(t) }
        end

        def perform_batch(arg)
        end

        def on_death(_, options)
          Output.call(options["args"].first)
        end
      end
    end

    it "runs the on_death callback when a batch fails", sidekiq: :fake do
      stub_const("TestJob", test_job)
      stub_const("Output", output = double("Output", call: nil))
      stub_batches

      test_job.new.perform(["test"])
      fail_one_batch

      expect(output).to have_received(:call).with(["test"])
    end
  end

  describe "the generated batch class" do
    let(:job_superclass) do
      Class.new do
        include Sidekiq::Job

        def self.marker = "inherited from job superclass"
      end
    end

    let(:test_job) do
      Class.new(job_superclass) do
        include Simplekiq::BatchingJob

        def perform_batching(arg)
          queue_batch(arg)
        end

        def perform_batch(arg)
        end
      end
    end

    before do
      stub_const("TestJob", test_job)
    end

    it "inherits from the including job's own superclass, not a gem-owned base class" do
      expect(TestJob::SimplekiqBatch.superclass).to eq(job_superclass)
      expect(TestJob::SimplekiqBatch.marker).to eq("inherited from job superclass")
    end

    it "still performs batches via perform_batch" do
      stub_const("Output", output = double("Output", call: nil))
      test_job.define_method(:perform_batch) { |arg| Output.call(arg) }

      test_job.new.perform("test")

      expect(output).to have_received(:call).with("test")
    end

    context "when the job has no explicit superclass" do
      let(:test_job) do
        Class.new do
          include Simplekiq::BatchingJob

          def perform_batching(arg)
            queue_batch(arg)
          end

          def perform_batch(arg)
          end
        end
      end

      it "falls back to Object" do
        stub_const("TestJob", test_job)

        expect(TestJob::SimplekiqBatch.superclass).to eq(Object)
      end
    end
  end

  describe "batch_sidekiq_options" do
    let(:test_job) do
      Class.new do
        include Simplekiq::BatchingJob

        batch_sidekiq_options queue: "test_queue"

        def perform_batching(arg)
          queue_batch(arg)
        end

        def perform_batch(arg)
          Output.call(arg)
        end
      end
    end

    it "sets the sidekiq options for the base class" do
      stub_const("Test", test_job)

      expect(Test::SimplekiqBatch.sidekiq_options).to eq("queue" => "test_queue", "retry" => true)
    end
  end
end
