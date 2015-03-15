class MessagePart < ActiveRecord::Base
  belongs_to :message

  validates :body, :sequence_number, :presence => true
end
