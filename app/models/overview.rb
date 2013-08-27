class Overview
  def initialize
    @new_users = {}
    @messages_received = {}
    @users_texting = {}
  end

  def new_users(options = {})
    @new_users[options] ||= User.overview_of_created(options)
  end

  def messages_received(options = {})
    @messages_received[options] ||= Message.overview_of_created(options)
  end

  def users_texting(options = {})
    new_options = options.merge(:by_user => true)
    @users_texting[new_options] ||= Message.overview_of_created(new_options)
  end

  def return_users(options = {})
    users = []
    new_users_hash = Hash[new_users(options)]
    new_users_hash.default = 0
    users_texting(options).each do |timestamp_with_count|
      timestamp = timestamp_with_count[0]
      users << [timestamp, timestamp_with_count[1] - new_users_hash[timestamp]]
    end
    users
  end

  def revenue(options = {})
    revenue_in_dollars = []
    messages_received(options).each do |timestamp_with_count|
      revenue_in_dollars << [timestamp_with_count[0], (timestamp_with_count[1] * ENV['REVENUE_PER_SMS'].to_f).round(2)]
    end
    revenue_in_dollars
  end

  def inbound_cdrs(options = {})
    InboundCdr.overview_of_created(options)
  end

  def phone_calls(options = {})
    PhoneCall.overview_of_created(options)
  end
end
