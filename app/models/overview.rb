class Overview
  attr_accessor :timeframe, :options

  def initialize(params = {})
    self.options = params.slice(:operator, :country_code)
    options.merge!(:least_recent => 3.months)
    @new_users = {}
    @messages_received = {}
    @users_texting = {}
    @inbound_cdrs = {}
    @phone_calls = {}
    @ivr_bill_minutes = {}
  end

  def timeframe=(value)
    options.merge!(:timeframe => value)
    @timeframe = value
  end

  def new_users
    @new_users[timeframe] ||= User.overview_of_created(options.dup)
  end

  def messages_received
    @messages_received[timeframe] ||= Message.overview_of_created(options.dup)
  end

  def users_texting
    @users_texting[timeframe] ||= Message.overview_of_created(options.merge(:by_user => true))
  end

  def return_users
    users = []
    new_users_hash = Hash[new_users]
    new_users_hash.default = 0
    users_texting.each do |timestamp_with_count|
      timestamp = timestamp_with_count[0]
      users << [timestamp, timestamp_with_count[1] - new_users_hash[timestamp]]
    end
    users
  end

  def inbound_cdrs
    @inbound_cdrs[timeframe] ||= InboundCdr.overview_of_created(options.dup)
  end

  def phone_calls
    @phone_calls[timeframe] ||= PhoneCall.overview_of_created(options.dup)
  end

  def ivr_bill_minutes
    @ivr_bill_minutes[timeframe] ||= InboundCdr.overview_of_duration(options.dup)
  end
end
