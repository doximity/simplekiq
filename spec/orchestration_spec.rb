# frozen_string_literal: true

RSpec.describe Simplekiq::Orchestration do
  let(:orchestration) { described_class.new }

  before do
    stub_const("OrcTest::JobA", Class.new)
    stub_const("OrcTest::JobB", Class.new)
  end

  describe "run" do
    subject { orchestration.serialized_workflow }

    context "when run is called without a description" do
      before do
        orchestration.run OrcTest::JobA, "syn"
      end

      it "adds a step" do
        expect(subject).to eq ([
          {"klass" => "OrcTest::JobA", "args" => ["syn"]}
        ])
      end
    end

    context "when run is called with a description" do
      before do
        orchestration.run OrcTest::JobA, "syn", description: "Some description"
      end

      it "adds a step" do
        expect(subject).to eq [
          {"description" => "Some description", "klass" => "OrcTest::JobA", "args" => ["syn"]}
        ]
      end
    end
  end

  describe "in_parallel" do
    subject { orchestration.serialized_workflow }

    context "when in_parallel is called without any run steps" do
      before do
        orchestration.in_parallel do
          # nothing
        end
      end

      it "does not add a step" do
        expect(subject).to be_empty
      end
    end

    context "when in_parallel is called with run steps" do
      context "when the description is not provided" do
        before do
          orchestration.in_parallel do
            orchestration.run OrcTest::JobA, "syn"
            orchestration.run OrcTest::JobB, "ack"
          end
        end

        it "adds a step" do
          expect(subject).to eq [
            {
              "jobs" => [
                {"klass" => "OrcTest::JobA", "args" => ["syn"]},
                {"klass" => "OrcTest::JobB", "args" => ["ack"]}
              ]
            }
          ]
        end
      end

      context "when the description is provided" do
        before do
          orchestration.in_parallel(description: "Some description") do
            orchestration.run OrcTest::JobA, "syn"
            orchestration.run OrcTest::JobB, "ack"
          end
        end

        it "adds a step with the description" do
          expect(subject).to eq ([
            {
              "description" => "Some description",
              "jobs" => [
                {"klass" => "OrcTest::JobA", "args" => ["syn"]},
                {"klass" => "OrcTest::JobB", "args" => ["ack"]},
              ],
            }
          ])
        end
      end
    end
  end
end
