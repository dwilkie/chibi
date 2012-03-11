module Communicable
  extend ActiveSupport::Concern

  included do
    attr_accessible :from

    belongs_to :user
    belongs_to :chat, :touch => true

    validates :user, :associated => true, :presence => true
    validates :from, :presence => true

    after_initialize :assign_to_user
  end

  private

  def assign_to_user
    self.user = User.find_or_initialize_by_mobile_number(from) unless user_id.present?
  end
end
