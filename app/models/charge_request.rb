class ChargeRequest < ActiveRecord::Base
  REMOTE_QUEUE = "charge_requester_queue"
  REMOTE_WORKER = "ChargeRequester"

  belongs_to :user
  belongs_to :requester, :polymorphic => true

  validates :user, :operator, :presence => true

  after_create :request_charge!

  state_machine :initial => :created do
    state :awaiting_result, :successful, :errored, :failed
  end

  private

  def request_charge!
    Resque::Job.create(REMOTE_QUEUE, REMOTE_WORKER, id, operator, user.mobile_number)
  end
end
