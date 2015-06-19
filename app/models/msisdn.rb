class Msisdn < ActiveRecord::Base
  has_many   :msisdn_discoveries

  validates :mobile_number,
            :presence => true,
            :uniqueness => true,
            :phony_plausible => true

  def blacklisted?
    blacklist.include?(mobile_number)
  end

  def activate!
    update_column(:active, true)
  end

  def deactivate!
    update_column(:active, false)
  end

  private

  def blacklist
    torasup_operator.blacklist || []
  end

  def torasup_operator
    @torasup_number ||= Torasup::PhoneNumber.new(mobile_number).operator
  end
end
