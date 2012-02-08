module HandlerHelpers
  def setup_handler(user, options = {})
    options[:message] ||= build(
      :message,
      :user => user,
      :body => options[:body],
      :from => user.mobile_number
    )

    subject.message = options[:message]
    subject.user = user
    subject.location = user.location
    subject.body = options[:message].body
  end
end
