class Reply < ActiveRecord::Base
  belongs_to :user
  belongs_to :chat

  validates :user, :presence => true
  validates :to, :presence => true

  alias_attribute :destination, :to

  before_validation :set_destination

  after_create :deliver

  def body
    read_attribute(:body).to_s
  end

  def logout_or_end_chat(options = {})
    self.body = I18n.t(
      "replies.logged_out_or_chat_has_ended",
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

  def introduce(partner)
    self.body = I18n.t(
      "replies.new_chat_started",
      :users_name => user.name,
      :friends_screen_name => partner.screen_id,
      :locale => user.locale
    )
    save
  end

  private

  def deliver
    nuntium = Nuntium.new ENV['NUNTIUM_URL'], ENV['NUNTIUM_ACCOUNT'], ENV['NUNTIUM_APPLICATION'], ENV['NUNTIUM_PASSWORD']
    nuntium.send_ao(:to => "sms://#{destination}", :body => body)
  end

  def set_destination
    self.destination ||= user.try(:mobile_number)
  end
end
