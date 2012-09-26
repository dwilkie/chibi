class Overview
  def new_users(options = {})
    User.overview_of_created(options)
  end

  def messages_received(options = {})
    Message.overview_of_created(options)
  end

  def users_texting(options = {})
    Message.overview_of_created(options.merge(:by_user => true))
  end
end
