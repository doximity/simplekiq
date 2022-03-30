require "bundler/setup"
require "simplekiq"
require "pry"

# Faking this because we can't vendor the source code into this gem for legal reasons
module Sidekiq
  class Batch
    def initialize
      @callbacks = {}
    end

    def description; end
    def description=(*); end

    def jobs(&block)
      block.call
    end

    # sidekiq_batch.on(:death, self.class, "args" => args)
    def on(event, klass, args)
      callbacks[event] ||= []
      callbacks[event] << {klass => args}
    end

    def callbacks
      @callbacks
    end
  end

  module Worker
    def batch
      nil
    end
  end
end

module SidekiqBatchTestHelpers
  # These helper methods only work in the following test mode:
  # sidekiq: :fake, stub_batches: false

  class NoBatchesError < StandardError
    def message
      "No batches queued. Ensure you the test has `stub_batches: false` and that you are actually queueing a batch"
    end
  end

  # https://github.com/mperham/sidekiq/issues/2700
  def stub_batches
    @batches = []
    allow_any_instance_of(Sidekiq::Batch).to receive(:jobs) do |batch, &block|
      block.call
      @batches << batch
    end
  end

  def fail_one_batch
    raise NoBatchesError if @batches.empty?
    raise "Tried to fail one batch but there were multiple batches" if @batches.length > 1

    @batches.first.callbacks["death"].each do |callback|
      callback.each do |klass, args|
        klass.new.send(:on_death, "death", args)
      end
    end
  end

  def succeed_all_batches
    current_batches = @batches
    @batches = []

    send_batch_callbacks_for(current_batches, "success")
    send_batch_callbacks_for(current_batches, "complete")
  end

  def send_batch_callbacks_for(current_batches, status)
    callback_symbol = "on_#{status}".to_sym
    current_batches.each do |batch|
      next unless batch.callbacks[status]

      batch.callbacks[status].each do |callback|
        callback.each do |klass, args| # callback is a hash
          klass.new.send(callback_symbol, status, args)
        end
      end
    end
  end

  def run_all_jobs_and_batches
    loops_left = 100
    while Sidekiq::Worker.jobs.any? || @batches.any?
      loops_left -= 1
      raise "no more loops!" if loops_left.negative?

      Sidekiq::Worker.drain_all # This will raise if any job fails
      succeed_all_batches # Because nothing raised, we can assume success for all batches
    end
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include SidekiqBatchTestHelpers, sidekiq: :fake
end
