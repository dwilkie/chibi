class ChargeRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :requester, :polymorphic => true

  include Chibi::Analyzable
  include AASM

  validates :user, :operator, :presence => true

  after_create :request_charge!

  aasm :column => :state, :whiny_transitions => false do
    state :created, :initial => true
    state :awaiting_result
    state :successful
    state :errored
    state :failed

    event :await_result do
      transitions(:from => :created, :to => :awaiting_result)
    end

    event :process_result, :after_commit => :notify_requester! do
      transitions(:from => :awaiting_result, :to => :successful, :if => :result_successful?)
      transitions(:from => :awaiting_result, :to => :failed, :if => :result_failed?)
      transitions(:from => :awaiting_result, :to => :errored)
    end
  end

  def self.charge_report(options = {})
    by_operator(options).between_dates(options).includes(:user).where(
      :state => :successful
    ).order(:id).pluck(*charge_report_columns)
  end

  def self.timeout!
    # timeout must be at least 24 hours to avoid the possibility of charging the user twice
    where(
      "state = ? OR state = ?", "awaiting_result", "created"
    ).where(
      "updated_at < ?", 24.hours.ago
    ).update_all(:state => "errored", :reason => "timeout")
  end

  # only returns false if the charge request is awaiting a result and the timeout has not been reached
  def slow?
    timeout = 20.seconds # only applies if previous charge failed (see user#charge!)
    (!awaiting_result? && !created?) || updated_at < timeout.ago
  end

  def set_result!(result, reason)
    self.result = result
    self.reason = reason
    process_result!
  end

  private

  def self.charge_report_columns(options = {})
    columns = {
      "transaction_id" => :id,
      "number" => "users.mobile_number",
      "timestamp" => :created_at,
      "result" => :state
    }
    options[:header] ? columns.keys : columns.values
  end

  def notify_requester!
    requester.charge_request_updated! if requester.present? && notify_requester?
  end

  def request_charge!
    Resque::Job.create(
      ENV["CHIBI_BILLER_CHARGE_REQUEST_QUEUE"],
      ENV["CHIBI_BILLER_CHARGE_REQUEST_WORKER"],
      id,
      operator,
      user.mobile_number
    )
    await_result!
  end

  def result_successful?
    result == "successful"
  end

  def result_failed?
    result == "failed"
  end
end
