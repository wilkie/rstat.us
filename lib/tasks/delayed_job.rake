require 'delayed_job'
require 'delayed_job_mongo_mapper'

namespace :jobs do
  desc "Spawn a temporary worker for 2 minutes."
  task :work do
    worker = Delayed::Worker.new(:min_priority => ENV['MIN_PRIORITY'], :max_priority => ENV['MAX_PRIORITY'], :quiet => false)
    Timeout.timeout(2.minutes.to_i) do
      worker.start
    end
  end

  desc "Clear all outstanding jobs."
  task :clear do
    Delayed::Job.delete_all
  end
end
