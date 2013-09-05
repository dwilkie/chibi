# stubs Redis for various resque plugins

module RedisHelpers
  require 'mock_redis'

  private

  def stub_redis(stubs = {})
    redis = MockRedis.new
    stub_const("REDIS", redis)
  end
end
