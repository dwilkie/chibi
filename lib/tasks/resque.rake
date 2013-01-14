require 'resque/tasks'
#require 'resque_scheduler/tasks'

# This is required when using Resque with Postgres
# http://stackoverflow.com/questions/7807733/resque-worker-failing-with-postgresql-server/7846127#7846127
task "resque:setup" => :environment do
  Resque.before_fork = Proc.new { ActiveRecord::Base.establish_connection }
end

desc "cleans stale workers"
task "resque:clean_stale_workers" => :environment do
  Resque::WorkerBoss.clean_stale_workers
end
