class Reply < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat

  validates :user, :presence => true
  validates :to, :presence => true

  alias_attribute :destination, :to

  before_validation :set_destination

  def self.filter_by(params = {})
    scoped.where(params.slice(:user_id)).order("created_at DESC")
  end

  def self.delivered
    scoped.where("delivered_at IS NOT NULL")
  end

  def self.undelivered
    scoped.where(:delivered_at => nil)
  end

  def body
    read_attribute(:body).to_s
  end

  def delivered?
    delivered_at.present?
  end

  def logout!(partner = nil)
    explain_how_to_start_a_new_chat!(:logout, :partner => partner)
  end

  def end_chat!(partner, options = {})
    explain_how_to_start_a_new_chat!(:no_answer, options.merge(:partner => partner))
  end

  def explain_chat_could_not_be_started!
    self.body = I18n.t(
      "replies.could_not_start_new_chat",
      :users_name => user.name,
      :locale => user.locale
    )
    deliver!
  end

  def explain_friend_is_unavailable!(partner)
    explain_how_to_start_a_new_chat!(:friend_unavailable, :partner => partner)
  end

  def forward_message(from, message)
    self.body = "#{from}: #{message}"
    save
  end

  def forward_message!(from, message)
    forward_message(from, message)
    deliver!
  end

  def introduce!(partner, to_initiator)
    self.body = I18n.t(
      "replies.new_chat_started",
      :users_name => user.name,
      :friends_screen_name => partner.screen_id,
      :to_initiator => to_initiator,
      :locale => user.locale
    )
    deliver!
  end

  def welcome!
    self.body = I18n.t("replies.welcome", :locale => user.locale)
    deliver!
  end

  def deliver!
    self.delivered_at = Time.now
    save
    nuntium = Nuntium.new ENV['NUNTIUM_URL'], ENV['NUNTIUM_ACCOUNT'], ENV['NUNTIUM_APPLICATION'], ENV['NUNTIUM_PASSWORD']
    # use an array so Nuntium sends a POST
    nuntium.send_ao([{:to => "sms://#{destination}", :body => body}])
  end

  private

  def set_destination
    self.destination ||= user.try(:mobile_number)
  end

  def explain_how_to_start_a_new_chat!(action, options = {})
    missing_profile_attributes = user.missing_profile_attributes unless options[:skip_update_profile_instructions]
    self.body = I18n.t(
      "replies.how_to_start_a_new_chat",
      :action => action,
      :friends_screen_name => options[:partner].try(:screen_id),
      :missing_profile_attributes => missing_profile_attributes,
      :locale => user.locale
    )
    deliver!
  end
end
