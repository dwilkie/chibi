# stubs Redis for various resque plugins

RSpec.configure do |config|
  config.before(:each) do
    # for resque-retry
    Resque.stub(:redis).and_return(mock(Redis, :incr => 0).as_null_object)
  end
end
