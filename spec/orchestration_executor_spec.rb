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

    it "kicks off the first step with a new batch" do
      batch_double = instance_double(Sidekiq::Batch)
      allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)
      expect(batch_double).to receive(:description=).with("FakeOrchestration Simplekiq orchestration")
      expect(batch_double).to receive(:on).with("success", FakeOrchestration, "args" => ["some", "args"])

      instance = instance_double(Simplekiq::OrchestrationExecutor)
      allow(Simplekiq::OrchestrationExecutor).to receive(:new).and_return(instance)
      expect(instance).to receive(:run_step).with(batch_double, workflow, 0)

      execute
    end

    context "when the workflow is empty" do
      let(:workflow) { [] }

      it "immediately calls the orchestration callbacks" do
        expect(job).to receive(:on_success).with(nil, "args" => ["some", "args"])

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
    let(:orchestration_batch) { instance_double(Sidekiq::Batch) }
    let(:step_batch) { instance_double(Sidekiq::Batch) }
    let(:step) { 0 }
    let(:instance) { described_class.new }

    it "runs the next job within a new step batch which is within the orchestration batch" do
      batch_stack = [] # to keep track of how deeply nested within batches we are
      expect(orchestration_batch).to receive(:jobs) do |&block|
        expect(batch_stack).to be_empty

        batch_stack.push("orchestration")
        block.call
        batch_stack.shift
      end
      expect(step_batch).to receive(:jobs) do |&block|
        expect(batch_stack).to eq ["orchestration"]
        batch_stack.push("step")
        block.call
        batch_stack.shift
      end

      expect(OrcTest::JobA).to receive(:perform_async) do |arg|
        expect(batch_stack).to eq ["orchestration", "step"]
        expect(arg).to eq 1
      end

      allow(Sidekiq::Batch).to receive(:new).and_return(step_batch)
      expect(step_batch).to receive(:on).with("success", described_class, {
        "orchestration_workflow" => workflow,
        "step" => 1
      })

      instance.run_step(orchestration_batch, workflow, 0)
    end
  end
end
