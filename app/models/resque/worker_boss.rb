module Resque
  class WorkerBoss
    def self.clean_stale_workers(options = {})
      stale_worker_jobs.each do |worker, job|
        worker.done_working
      end
    end

    private

    def self.stale_worker_jobs
      workers = Resque::Worker.working
      jobs = workers.collect {|w| w.job }
      workers.zip(jobs).reject do |w, j|
        w.idle? || j.empty? || j["run_at"].to_time > 10.minutes.ago
      end
    end
  end
end
