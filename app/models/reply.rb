class Reply < ActiveRecord::Base
  belongs_to :message
  belongs_to :subscription

  attr_accessible :body, :subscription
end

