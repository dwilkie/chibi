require 'spec_helper'

describe Resque::WorkerBoss do
  describe ".clean_stale_workers" do
    def build_job(started_at)
       {
        "queue" => "queue",
        "run_at" => started_at.to_s,
        "payload" => {"class"=>"Worker", "args"=>[]}
      }
    end

    def build_worker(job)
      double(Resque::Worker, :job => job, :idle? => false)
    end

    let(:stale_worker) { build_worker(build_job(11.minutes.ago)) }
    let(:worker) { build_worker(build_job(9.minutes.ago)) }

    before do
      Resque::Worker.stub(:working).and_return([stale_worker, worker])
    end

    it "should mark stale workers as 'done_working'" do
      stale_worker.should_receive(:done_working)
      worker.should_not_receive(:done_working)
      subject.class.clean_stale_workers
    end
  end
end
