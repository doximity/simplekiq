# Simplekiq

Any time that you find yourself needing to string together a long chain of jobs, particularly when there are multiple stages of Sidekiq-pro batches and callbacks involved, come home instead to the simple flavor of orchestrated job flow with Simplekiq.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simplekiq'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install simplekiq

## Usage

There are currently two primary components of the system which were designed to work in harmony:

* [Simplekiq::OrchestrationJob](./lib/simplekiq/orchestration_job.rb) - A mixin for a Sidekiq jobs to be able to orchestrate a flow of jobs in one place. It makes long complicated flows between jobs easier to understand, iterate on, and test. It eliminates the need to hop between dozens of files to determine when, where, and why a particular job gets called.
* [Simplekiq::BatchingJob](./lib/simplekiq/batching_job.rb) - A mixin designed to make breaking a large job into a batched process dead simple and contained within a single class while still being trivially composable in orchestrations.

## Tool Drilldown

### Simplekiq::OrchestrationJob

Mixing in the [Simplekiq::Orchestration](./lib/simplekiq/orchestration_job.rb) module lets you define a human-readable workflow of jobs in a single file with almost* no special requirements or restrictions on how the child jobs are designed. In most cases, Sidekiq jobs not designed for use in orchestrations should be compatible for use in orchestrations. A job implementing `OrchestrationJob` might look like:

```ruby
class SomeOrchestrationJob < BaseJob
  include Sidekiq::Worker
  include Simplekiq::OrchestrationJob

  def perform_orchestration(some_id)
    @some_model = SomeModel.find(some_id) # 1.

    run SomeInitialSetupJob, some_model.id # 2.

    in_parallel do
      some_related_models.each do |related_model|
        run SomeParallelizableJob, related_model.id # 3.
      end
    end

    run SomeFinalizationJob, some_model.id # 4.
  end

  private

  attr_reader :some_model

  def some_related_models
    @some_related_models ||= some_model.some_relation
  end
end
```

Let's use the above example to describe some specifics of how the flow works.

1. `SomeOrchestrationJob` pulls up some instance of parent model `SomeModel`.
2. It does some initial work in `SomeInitialSetupJob`, which blocks the rest of the workflow until it completes successfully.
3. Then it will run a `SomeParallelizableJob` for each of some number of associated models `some_related_models`. These jobs will all run parallel to each other independently.
4. Finally, after all of the parallel jobs from #3 complete successfully, `SomeFinalizationJob` will run and then after it finishes the orchestration will be complete.

**Note** - it's fine to add utility methods and `attr_accessor`s to keep the code tidy and maintainable.

When `SomeOrchestrationJob` itself gets called though, the first thing it does it turn these directives into a big serialized structure indicating which job will be called under what conditions (eg, serial or in parallel) and with what arguments, and then keeps passing that between the simplekiq-internal jobs that actually conduct the flow.

This means when you want to deploy a change to this flow all previous in-flight workflows will continue undisturbed because the workflow is frozen in sidekiq job arguments and will remain frozen until the workflow completes. This is generally a boon, but note that if you remove a job from a workflow you'll need to remember to either keep the job itself (eg, the `SomeFinalizationJob` class file from our above example) in the codebase or replace it with a stub so that any in-flight workflows won't crash due to not being able to pull up the prior-specified workflow.

"almost* no special requirements or restrictions on how the child jobs are designed" - The one thing you'll want to keep in mind when feeding arbitrary jobs into orchestrations is that if the job creates any new sidekiq batches then those new sidekiq batches should be added as child sidekiq batches of the parent sidekiq batch of the job. The parent sidekiq batch of the job is the sidekiq batch that drives the orchestration from step to step, so if you don't do this it will move onto the next step in the orchestration once your job finishes even if the new sidekiq batches it started didn't finish. This sounds more complicated than it is, you can see an example of code that does this in [`BatchingJob#perform`](./lib/simplekiq/batching_job.rb):

```ruby
if batch # is there a parent batch?
  batch.jobs do # open the parent batch back up
    create_a_new_batch_and_add_jobs_to_it_to_run # make our new batch as a child batch of the parent batch
  end # close the parent batch again
else # there's no parent batches, this job was run directly outside of an orchestration
  create_a_new_batch_and_add_jobs_to_it_to_run # make our new batch without a parent batch
end
```

### Simplekiq::BatchingJob

See the [Simplekiq::BatchingJob](./lib/simplekiq/batching_job.rb) module itself for a description and example usage in the header comments. Nutshell is that you should use this if you're planning on making a batched asynchronous process as it shaves off a lot of ceremony and unexpressive structure. eg - Instead of having `BeerBottlerJob` which queues some number of `BeerBottlerBatchJob`s to handle the broken down sub-tasks you can just have `BeerBottlerJob` with a method for batching, executing individual batches, and a callback that gets run after all batches have completed successfully.

## History

Simplekiq was initially released for private use within Doximity applications in Oct 2020 where it continued to be iterated on towards stability and general use until Jan 2022 when it was deemed settled enough for public release.

The primary driving factor that inspired this work was a series of over a dozen differently defined and structured jobs part of a single workflow of which the logical flow was extraordinarily difficult to cognitively trace. This led to exteme difficulty in debugging and following problematic instances of the workflow in production as well as needlessly high cost to refactoring and iterative adjustments.

The crux of the problem was that each job was highly coupled to its position in the overall flow as well as the absence of any central mechanism to indicate what the overall flow was. After building Simplekiq and implementing it into the flow, significant changes to the flow became quick adjustments requiring only a couple lines of code to change and folks unfamiliar with the system could quickly get up to speed by reading through the orchestration job.

## Versioning

This project follows semantic versioning. At time of writing it is sitting at 0.0.1 until its integration with the application it was extracted from is confirmed to be stable. Once confirmed it will be started off at 1.0.0 as it has otherwise been used in a production system already for some time.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Note that this depends on `sidekiq-pro` which requires a [commercial license](https://sidekiq.org/products/pro.html) to install and use.

Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

TODO: Update this section with more specific/appropriate instructions once this is a public repository.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
6. Sign the CLA if you haven't yet. See CONTRIBUTING.md

## License

The gem is licensed under an Apache 2 license. Contributors are required to sign an contributor license agreement. See LICENSE.txt and CONTRIBUTING.md for more information.
