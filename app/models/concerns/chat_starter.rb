module ChatStarter
  extend ActiveSupport::Concern

  included do
    has_many :triggered_chats, :as => :starter, :class_name => "Chat"
  end
end
