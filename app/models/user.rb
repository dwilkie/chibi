class User < ActiveRecord::Base
  has_many :user_interests
  has_many :interests, :through => :user_interests

  has_many :mo_messages
  has_many :mt_messages

  validates :mobile_number, :username, :uniqueness => true

  before_validation(:on => :update) do
    self.username = name.gsub(/\s+/, "") << id.to_s if attribute_present?(:name) && persisted?
  end

  state_machine :initial => :newbie do
    event :rock do
      transition [:newbie] => :rocking
    end
  end

  def self.matches(user, limit = 5)
    where(:sex => user.looking_for).limit(limit)
  end

#  STATUS = {
#    :newbie => 'newbie',
#    :registering => 'registering',
#    :ready => 'ready',
#    :looking_for => 'looking_for',
#    :rocking => 'rocking'
#  }

#  def parse!(text)
#    handler.process! text, self
#  end

#  def handler
#    "#{self.status}_handler".classify.constantize.new
#  end

#  def update_status(value)
#    self.status = STATUS[value]
#  end

#  def start_match
#    matches = []
#    interests.each do |interest|
#      matches << interest.users
#    end
#    self.suggestions = matches.uniq.map(&:profile_details).map(&:split).map(&:first)
#  end
end

