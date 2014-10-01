module Resque
  class WorkerBoss
    SLOWEST_JOB = (ENV["SLOWEST_WORKER"] || 30).to_i # minutes

    def self.clean_stale_workers
      Resque.workers.each do |worker|
        worker.unregister_worker if old_worker?(worker)
      end
    end

    private

    # only workers that are currently working will return processing info.
    # Old jobs which have finished will return an empty hash

    def self.old_worker?(worker)
      worker.processing.empty? || Time.now - worker.processing["run_at"].to_time > 60 * SLOWEST_JOB
    end

    private_class_method :old_worker?
  end
end
