class MessageHandler
  attr_accessor :user

  def initialze(user)
    self.user = user
  end

  def process!(text)
    "#{user.state}_handler".classify.constantize.process! text
  end

  protected

  def reply(text)
    user.mt_messages.create(:body => text)
  end

end

