class Reply < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat

  validates :user, :presence => true
  validates :to, :presence => true

  alias_attribute :destination, :to

  before_validation :set_destination

  def body
    read_attribute(:body).to_s
  end

  def logout_or_end_chat(options = {})
    self.body = I18n.t(
      "replies.logged_out_or_chat_has_ended",
      :friends_screen_name => options[:partner].try(:screen_id),
      :missing_profile_attributes => user.missing_profile_attributes,
      :logged_out => options[:logout],
      :locale => user.locale
    )
    save
  end

  def explain_chat_could_not_be_started
    self.body = I18n.t(
      "replies.could_not_start_new_chat",
      :users_name => user.name,
      :locale => user.locale
    )
    save
  end

  def forward_message(from, message)
    self.body = "#{from}: #{message}"
    save
  end

  def introduce(partner, options = {})
    self.body = I18n.t(
      "replies.new_chat_started",
      :users_name => user.name,
      :friends_screen_name => partner.screen_id,
      :old_friends_screen_name => options[:old_friends_screen_name],
      :to_user => options[:to_user],
      :locale => user.locale
    )
    save
  end

  private

  def set_destination
    self.destination ||= user.try(:mobile_number)
  end
end
