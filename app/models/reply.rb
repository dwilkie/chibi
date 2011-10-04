class Reply < ActiveRecord::Base
  belongs_to :chat
  belongs_to :subscription

  attr_accessible :body, :subscription
end

