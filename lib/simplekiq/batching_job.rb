# frozen_string_literal: true

# This module enables you to break up your work into batches and run those
# batches as background jobs while keeping all your code in the same file.
# Including this module *implements perform* you should not override it.
# It expects you to implement two methods: #perform_batching and #perform_batch.
# Optionally you may also implement #on_success or #on_death
#
# #perform_batching should contain your code for breaking up your work into smaller jobs.
# It handles all the Sidekiq::Batch boilerplate for you. Where you would normally call ExampleBatchJob.perform_async
# you should use #queue_batch. If you'd like to custommize the sidekiq batch
# object, you can access it in perform_batching through the `sidekiq_batch` method.
#
# #perform_batch should contain the code that would be in your batch job. Under the hood #queue_batch
# queues a job which will run #perform_batch.
#
# See Sidekiq::Batch documentation for the signatures and purpose of #on_success and #on_death
#
# class ExampleJob
#   include Simplekiq::BatchingJob
#
#   def perform_batching(some_id)
#     sidekiq_batch.description = "My custom batch description" # optional
#
#     Record.find(some_id).other_records.in_batches do |other_records|
#       queue_batch(other_records.ids)
#     end
#   end
#
#   def perform_batch(other_record_ids)
#     OtherRecord.where(id: other_record_ids).do_work
#   end
#
#   def on_success(_status, options)
#     same_id_as_before = options["args"].first
#     Record.find(same_id_as_before).success!
#   end
# end
#
# ExampleJob.perform_async(some_id)
#
# Come home to the impossible flavor of batch creation

module Simplekiq
  module BatchingJob
    BATCH_CLASS_NAME = "SimplekiqBatch"

    class << self
      def included(klass)
        batch_job_class = Class.new(BaseBatch)
        klass.const_set(BATCH_CLASS_NAME, batch_job_class)
      end
    end

    def perform(*args)
      perform_batching(*args)
      handle_batches(args)
    end

    protected

    attr_accessor :batches

    def handle_batches(args)
      if batches.present?
        flush_batches(args)
      elsif respond_to?(:on_success)
        on_success(nil, { "args" => args })
      end
    end

    def flush_batches(args)
      batch_job_class = self.class.const_get(BATCH_CLASS_NAME)
      sidekiq_batch.description ||= "Simplekiq Batch Jobs for #{self.class.name}, args: #{args}"

      sidekiq_batch.on(:death, self.class, "args" => args) if respond_to?(:on_death)
      sidekiq_batch.on(:success, self.class, "args" => args) if respond_to?(:on_success)

      sidekiq_batch.jobs do
        batches.each do |job_args|
          batch_job_class.perform_async(*job_args)
        end
      end
    end

    def queue_batch(*args)
      self.batches ||= []
      self.batches << args
    end

    def sidekiq_batch
      @sidekiq_batch ||= Sidekiq::Batch.new
    end
  end

  class BaseBatch
    include Sidekiq::Worker

    def perform(*args)
      self.class.parent.new.perform_batch(*args)
    end
  end
end
