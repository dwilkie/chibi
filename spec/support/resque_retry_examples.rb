shared_examples_for "rescheduling redis max client errors" do |max_tries|
  max_tries ||= 5

  let(:redis_mock) { mock(Redis).as_null_object }

  before do
    redis_mock.stub(:incr).and_return(*((1..max_tries).to_a))
    Resque.stub(:redis).and_return(redis_mock)
  end

  context "given a 'Redis::CommandError - ERR max number of clients reached' is raised" do
    before do
      subject.class.stub(:perform).and_raise(
        Redis::CommandError.new("ERR max number of clients reached")
      )
    end

    it "should reschedule the job immediately" do
      subject.class.should_receive(:perform).exactly(max_tries).times
      with_resque do
        expect { Resque.enqueue(subject.class) }.to raise_error(Redis::CommandError)
      end
    end
  end

  context "given some other error is raised" do
    before do
      subject.class.stub(:perform).and_raise(ArgumentError)
    end

    it "should not reschedule the job" do
      Resque.should_not_receive(:enqueue_in)
      with_resque do
        expect { Resque.enqueue(subject.class) }.to raise_error(ArgumentError)
      end
    end
  end
end
