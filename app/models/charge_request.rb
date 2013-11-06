class ChargeRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :requester, :polymorphic => true

  validates :user, :operator, :presence => true

  after_create :request_charge!

  state_machine :initial => :created do
    state :awaiting_result, :successful, :errored, :failed

    event :await_result do
      transition(:created => :awaiting_result)
    end
  end

  # only returns false if the charge request is awaiting a result and the timeout has not been reached
  def slow?
    timeout = 5.seconds
    (!awaiting_result? && !created?) || updated_at < timeout.ago
  end

  private

  def request_charge!
    Resque::Job.create(
      ENV["CHIBI_BILLER_CHARGE_REQUEST_QUEUE"],
      ENV["CHIBI_BILLER_CHARGE_REQUEST_WORKER"],
      id,
      operator,
      user.mobile_number
    )
    await_result
  end
end
