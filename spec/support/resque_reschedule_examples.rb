shared_examples_for "rescheduling SIGTERM exceptions" do
  context "given a 'Resque::TermException' is raised" do
    before do
      error_stub.and_raise(Resque::TermException.new("SIGTERM"))
    end

    it "should reschedule the job immediately" do
      Resque.should_receive(:enqueue).with(subject.class, *args)
      subject.class.perform(*args)
    end
  end

  context "given some other error is raised" do
    before do
      error_stub.and_raise(ArgumentError)
    end

    it "should not reschedule the job" do
      Resque.should_not_receive(:enqueue)
      expect { subject.class.perform(*args) }.to raise_error(ArgumentError)
    end
  end
end
