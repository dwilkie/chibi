class User < ActiveRecord::Base
  has_many :user_interests
  has_many :interests, :through => :user_interests

  has_many :mo_messages
  has_many :mt_messages

  validates :mobile_number, :presence => true, :uniqueness => true
  validates :username, :uniqueness => true

  before_validation(:on => :update) do
    self.username = name.gsub(/\s+/, "") << id.to_s if attribute_present?(:name) && persisted?
  end

  state_machine :initial => :newbie do
    event :register_details do
      transition [:newbie] => :registered_details
    end

    event :register_interests do
      transition [:registered_details] => :registered_interests
    end

    event :register_looking_for do
      transition [:registered_interests] => :ready
    end
  end

  def self.match_sex(user)
    user.looking_for.present? ? where(:sex => user.looking_for) : scoped
  end

  def self.ready
    where(:state => "ready")
  end

  def self.matches(user, limit = 5)
    match_sex(user).ready.limit(limit)
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

