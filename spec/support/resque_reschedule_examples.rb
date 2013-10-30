shared_examples_for "rescheduling SIGTERM exceptions" do
  context "given a 'Resque::TermException' is raised" do
    it "should reschedule the job immediately" do
      Resque.should_receive(:enqueue).with(subject.class, *args)
      expect { subject.class.on_failure_retry(Resque::TermException.new("SIGTERM"), *args) }.to raise_error(Resque::DontFail)
    end
  end

  context "given some other error is raised" do
    it "should not reschedule the job" do
      Resque.should_not_receive(:enqueue)
      subject.class.on_failure_retry(StandardError.new, *args)
    end
  end
end
