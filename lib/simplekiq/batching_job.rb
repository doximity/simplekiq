# frozen_string_literal: true

# This module enables you to break up your work into batches and run those
# batches as background jobs while keeping all your code in the same file.
# Including this module *implements perform* you should not override it.
# It expects you to implement two methods: #perform_batching and
# #perform_batch.
#
# Optionally you may also implement any combination of Sidekiq::Batch
# callbacks.
#   - #on_complete
#   - #on_success
#   - #on_death
#
# #perform_batching should contain your code for breaking up your work into
# smaller jobs. It handles all the Sidekiq::Batch boilerplate for you. Where
# you would normally call ExampleBatchJob.perform_async you should use
# #queue_batch. If you'd like to custommize the sidekiq batch object, you can
# access it in perform_batching through the `sidekiq_batch` method.
#
# #perform_batch should contain the code that would be in your batch job. Under
# the hood, #queue_batch queues a job which will run #perform_batch.
#
# [Sidekiq::Batch documentation](https://github.com/mperham/sidekiq/wiki/Batches)
# explains batches, their lifecycle, callbacks, etc.
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
#   def on_death(_status, options)
#     same_id_as_before = options["args"].first
#     Record.find(same_id_as_before).death!
#   end

#   def on_complete(_status, options)
#     same_id_as_before = options["args"].first
#     Record.find(same_id_as_before).complete!
#   end

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
    include Sidekiq::Worker

    BATCH_CLASS_NAME = "SimplekiqBatch"

    class << self
      def included(klass)
        batch_job_class = Class.new(BaseBatch)
        klass.const_set(BATCH_CLASS_NAME, batch_job_class)

        klass.extend ClassMethods
      end
    end

    module ClassMethods
      def batch_sidekiq_options(options)
        batch_class = const_get(BATCH_CLASS_NAME)
        batch_class.instance_eval do
          sidekiq_options(options)
        end
      end
    end

    def perform(*args)
      self.batches = []

      perform_batching(*args)

      # If we're part of an existing sidekiq batch make this a child batch
      # This is necessary for it work with orchestration; we could add an option
      # to toggle the behavior on and off.
      if batch
        batch.jobs do
          handle_batches(args)
        end
      else
        handle_batches(args)
      end
    end

    protected # TODO: should this be private?

    attr_accessor :batches

    def handle_batches(args)
      if !batches.empty?
        flush_batches(args)
      else
        # Empty batches with no jobs will never invoke callbacks, so handle
        # that case by immediately manually invoking :complete & :success.
        on_complete(nil, { "args" => args }) if respond_to?(:on_complete)
        on_success(nil, { "args" => args }) if respond_to?(:on_success)
      end
    end

    def flush_batches(args)
      batch_job_class = self.class.const_get(BATCH_CLASS_NAME)
      sidekiq_batch.description ||= "Simplekiq Batch Jobs for #{self.class.name}, args: #{args}"

      sidekiq_batch.on(:death, self.class, "args" => args) if respond_to?(:on_death)
      sidekiq_batch.on(:complete, self.class, "args" => args) if respond_to?(:on_complete)
      sidekiq_batch.on(:success, self.class, "args" => args) if respond_to?(:on_success)

      sidekiq_batch.jobs do
        batches.each do |job_args|
          batch_job_class.perform_async(*job_args)
        end
      end
    end

    def queue_batch(*args)
      self.batches << args
    end

    def batch_description=(description)
      sidekiq_batch.description = description
    end

    private

    def sidekiq_batch
      @sidekiq_batch ||= Sidekiq::Batch.new
    end
  end

  class BaseBatch
    include Sidekiq::Worker

    def perform(*args)
      module_parent_of_class.new.perform_batch(*args)
    end

    private

    def module_parent_of_class
      # Borrowed from https://apidock.com/rails/Module/module_parent_name
      parent_name = self.class.name =~ /::[^:]+\Z/ ? $`.freeze : nil
      parent_name ? Object.const_get(parent_name) : Object
    end
  end
end
