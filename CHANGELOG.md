# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0]
* `Simplekiq::BatchingJob`-generated batch classes (`<Job>::SimplekiqBatch`) now
  inherit from the including job's own superclass instead of a dedicated
  `Simplekiq::BaseBatch` class, so they automatically pick up whatever that
  superclass provides (retry defaults, logging hooks, kill switches, etc.) the
  same way any other subclass would.
  **Behavior change:** batch classes that never call `batch_sidekiq_options`
  used to fall back to Sidekiq's global default options; they now fall back to
  whatever Sidekiq options the job's superclass configures instead. Explicit
  `batch_sidekiq_options` calls are unaffected and still take precedence. The
  including job's *own* per-class `sidekiq_options` overrides are still not
  inherited by the batch class (this was already true before this change),
  since the batch class is a sibling of the job, not a subclass of it.

## [1.0.0]
* Only support Sidekiq 7.1 and Sidekiq 8 (dropped support for older versions)
  [#42](https://github.com/doximity/simplekiq/pull/42)

## [0.1.0] (pre-release for 1.0)
* Fix typo in CONTRIBUTORS
  [#5](https://github.com/doximity/simplekiq/pull/5)
* Fix incorrectly named spec file
  [#9](https://github.com/doximity/simplekiq/pull/9)
* README fix
  [#10](https://github.com/doximity/simplekiq/pull/10)
* Updating CONTRIBUTING license
  [#16](https://github.com/doximity/simplekiq/pull/16)
* Fix CHANGELOG typo
  [#18](https://github.com/doximity/simplekiq/pull/18)
* Add sidekiq-pro as an explicit dependency and loosen sidekiq requirements
  [#19](https://github.com/doximity/simplekiq/pull/19)
* Add new toplevel batch to encapsulate all batches within an orchestration
  [#21](https://github.com/doximity/simplekiq/pull/21)
* Fix bug with toplevel batch and include batch descriptions
  [#23](https://github.com/doximity/simplekiq/pull/23)

## [0.0.3]
* Misc minimal fixes to get the gem building and releasable according to our open source standards
  [#3](https://github.com/doximity/simplekiq/pull/3)
* Copy over library code from prior sources with maintained history
  [#2](https://github.com/doximity/simplekiq/pull/2)

## [0.0.2]
* Scrubbed version from rubygems, do not use
## [0.0.1]
* Scrubbed version from rubygems, do not use
