module HandlerHelpers
  def setup_handler(user)
    subject.user = user
    subject.location = user.location
    subject.body = ""
  end
end
