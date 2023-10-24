# frozen_string_literal: true

RSpec.describe Simplekiq::OrchestrationExecutor do
  let(:workflow) do
    [
      {"klass" => "OrcTest::JobA", "args" => [1]}
    ]
  end

  let!(:job) do
    stub_const("FakeOrchestration", Class.new do
      def on_success(status, options)
      end
    end)

    FakeOrchestration.new
  end

  before { stub_const("OrcTest::JobA", Class.new) }

  describe ".execute" do
    def execute
      described_class.execute(args: ["some", "args"], job: job, workflow: workflow)
    end

    it "kicks off the first step with a new batch with the empty tracking batch inside it" do
      batch_double = instance_double(Sidekiq::Batch, bid: 42)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
      expect(batch_double).to receive(:description=).with("FakeOrchestration Simplekiq orchestration")
      expect(batch_double).to receive(:on).with("success", FakeOrchestration, "args" => ["some", "args"])

      batch_stack_depth = 0 # to keep track of how deeply nested within batches we are
      expect(batch_double).to receive(:jobs) do |&block|
        batch_stack_depth += 1
        block.call
        batch_stack_depth -= 1
      end

      expect(Simplekiq::BatchTrackerJob).to receive(:perform_async) do
        expect(batch_stack_depth).to eq 1
      end

      instance = instance_double(Simplekiq::OrchestrationExecutor)
      allow(Simplekiq::OrchestrationExecutor).to receive(:new).and_return(instance)
      expect(instance).to receive(:run_step) do |workflow_arg, step|
        expect(batch_stack_depth).to eq 1
        expect(step).to eq 0
      end

      execute
    end

    context "when the workflow is empty" do
      let(:workflow) { [] }

      it "immediately calls the orchestration callbacks" do
        expect(job).to receive(:on_success).with(nil, hash_including("args" => ["some", "args"]))

        execute
      end

      it "doesn't create new batches or run any steps" do
        expect(Sidekiq::Batch).not_to receive(:new)
        expect(described_class).not_to receive(:new)

        execute
      end
    end
  end

  describe "run_step" do
    let(:step_batch) { instance_double(Sidekiq::Batch) }
    let(:step) { 0 }
    let(:instance) { described_class.new }

    it "runs the next job within a new step batch" do
      batch_stack_depth = 0 # to keep track of how deeply nested within batches we are
      expect(step_batch).to receive(:jobs) do |&block|
        batch_stack_depth += 1
        block.call
        batch_stack_depth -= 1
      end

      expect(OrcTest::JobA).to receive(:perform_async) do |arg|
        expect(batch_stack_depth).to eq 1
        expect(arg).to eq 1
      end

      allow(Sidekiq::Batch).to receive(:new).and_return(step_batch)
      expect(step_batch).to receive(:on).with("success", described_class, {
        "orchestration_workflow" => workflow,
        "step" => 1
      })
      expect(step_batch).to receive(:description=).with("Simplekiq orchestrated step 1")

      instance.run_step(workflow, 0)
    end
  end
end
