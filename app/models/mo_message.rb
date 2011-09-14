class MoMessage < ActiveRecord::Base
  belongs_to :user

  attr_accessible :from, :body, :guid

  def origin(with_protocol = false)
    origin_without_protocol = from =~ %r(^(.*?)://(.*?)$) ? $2 : from
    with_protocol ? "sms://#{origin_without_protocol}" : origin_without_protocol
  end

  def process!
    MessageHandler.new(user).process! body
  end
end

