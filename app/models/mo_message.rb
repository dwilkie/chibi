class MoMessage < ActiveRecord::Base
  attr_accessible :from, :body, :guid

  def process!
    user = User.find_or_create_by_phone_number from.without_protocol
    user.parse! body
  end
end

