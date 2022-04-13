# frozen_string_literal: true

require "rspec/core/rake_task"

FileList["tasks/*.rake"].each { |task| load task }

RSpec::Core::RakeTask.new(:spec)

task default: :spec
