# frozen_string_literal: true

RSpec.describe Simplekiq do
  before do
    stub_const("OrcTest::BasicJob", Class.new)

    stub_const("OrcTest::CallbacksJob", Class.new do
      def on_complete(status, options)
      end

      def on_success(status, options)
      end

      def on_death(status, options)
      end
    end)
  end

  it "has a version number" do
    expect(Simplekiq::VERSION).not_to be nil
  end

  describe ".run_empty_callbacks" do
    let(:args) { [1, 2, 3] }
    let(:job) { OrcTest::CallbacksJob.new }

    def call
      Simplekiq.run_empty_callbacks(job, args: args)
    end

    it "calls the on_success and on_complete callback methods on the job" do
      expect(job).to receive(:on_complete).with(nil, "args" => [1, 2, 3])
      expect(job).to receive(:on_success).with(nil, "args" => [1, 2, 3])
      call
    end

    it "does not call on_death" do
      expect(job).not_to receive(:on_death)
      call
    end

    context "when the job does not define the callback methods" do
      let(:job) { OrcTest::BasicJob.new }

      it "does not call any callbacks" do
        # This approach ends up making the object appear to `respond_to?` each method because of the spy rspec adds
        # expect(job).not_to receive(:on_complete)
        # expect(job).not_to receive(:on_success)
        # expect(job).not_to receive(:on_death)

        # so instead, just:
        expect { call }.not_to raise_error
        # since it'd raise a NoMethodError if it tried to call them for this class
      end
    end
  end

  describe ".auto_define_callbacks" do
    let(:batch) { instance_double(Sidekiq::Batch) }
    let(:args) { [1, 2, 3] }
    let(:job) { OrcTest::CallbacksJob.new }

    def call
      Simplekiq.auto_define_callbacks(batch, args: args, job: job)
    end

    it "defines callbacks on the batch for every callback the job defines" do
      expect(batch).to receive(:on).once.ordered.with("death", OrcTest::CallbacksJob, "args" => [1,2,3])
      expect(batch).to receive(:on).once.ordered.with("complete", OrcTest::CallbacksJob, "args" => [1,2,3])
      expect(batch).to receive(:on).once.ordered.with("success", OrcTest::CallbacksJob, "args" => [1,2,3])
      call
    end

    context "when the job does not define the callback methods" do
      let(:job) { OrcTest::BasicJob.new }

      it "does not define any callbacks" do
        expect(batch).not_to receive(:on)
        call
      end
    end
  end
end
