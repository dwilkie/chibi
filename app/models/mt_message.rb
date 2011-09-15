class MtMessage < ActiveRecord::Base
  belongs_to :user
  after_create :deliver!

  def deliver!
    Nuntium.send_mt attributes.slice("body").merge("to" => user.mobile_number)
  end

end

