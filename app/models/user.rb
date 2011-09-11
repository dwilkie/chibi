class User < ActiveRecord::Base
  has_and_belongs_to_many :interests, :join_table => 'user_interests'

  STATUS = {
    :newbie => 'newbie',
    :registering => 'registering',
    :ready => 'ready',
    :looking_for => 'looking_for',
    :rocking => 'rocking'
  }

  def parse!(text)
    handler.process! text, self
  end

  def handler
    "#{self.status}_handler".classify.constantize.new
  end

  def update_status(value)
    self.status = STATUS[value]
  end

  def start_match
    matches = []
    interests.each do |interest|
      matches << interest.users
    end
    self.suggestions = matches.uniq.map(&:profile_details).map(&:split).map(&:first)
  end
end
