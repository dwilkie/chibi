class Overview
  def new_users(options = {})
    @new_users ||= User.overview_of_created(options)
  end

  def messages_received(options = {})
    @messages_received ||= Message.overview_of_created(options)
  end

  def users_texting(options = {})
    @users_texting ||= Message.overview_of_created(options.merge(:by_user => true))
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

  def profit(options = {})
    profit_in_dollars = []
    messages_received(options).each do |timestamp_with_count|
      profit_in_dollars << [timestamp_with_count[0], timestamp_with_count[1] * ENV['REVENUE_PER_SMS'].to_f]
    end
    profit_in_dollars
  end
end
