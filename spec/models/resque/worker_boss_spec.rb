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
      double(Resque::Worker, :processing => job, :idle? => false)
    end

    let(:stale_worker) { build_worker(build_job(30.minutes.ago)) }
    let(:worker) { build_worker(build_job(29.minutes.ago)) }
    let(:old_worker) { build_worker({})}

    before do
      Resque.stub(:workers).and_return([stale_worker, worker, old_worker])
    end

    it "should unregister the stale workers" do
      stale_worker.should_receive(:unregister_worker)
      old_worker.should_receive(:unregister_worker)
      worker.should_not_receive(:unregister_worker)
      subject.class.clean_stale_workers
    end
  end
end
