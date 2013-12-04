class ChargeRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :requester, :polymorphic => true

  include Chibi::Analyzable

  validates :user, :operator, :presence => true

  after_create :request_charge!

  state_machine :initial => :created do
    state :awaiting_result, :successful, :errored, :failed

    after_transition :awaiting_result => [:successful, :failed, :errored], :do => :notify_requester!

    event :await_result do
      transition(:created => :awaiting_result)
    end

    event :process_result do
      transition(:awaiting_result => :successful, :if => :result_successful?)
      transition(:awaiting_result => :failed, :if => :result_failed?)
      transition(:awaiting_result => :errored)
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
    process_result
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
    await_result
  end

  def result_successful?
    result == "successful"
  end

  def result_failed?
    result == "failed"
  end
end
