module HandlerHelpers
  def setup_handler(user, options = {})
    subject.user = user
    subject.location = user.location
    subject.body = options[:body] || ""
  end
end
