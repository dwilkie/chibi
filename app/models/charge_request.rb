class ChargeRequest < ActiveRecord::Base
  belongs_to :user
  belongs_to :requester, :polymorphic => true

  include Chibi::Analyzable
  include AASM

  DEFAULT_LONG_TIMEOUT_DURATION_HOURS = 24
  DEFAULT_SHORT_TIMEOUT_DURATION_SECONDS = 20

  validates :user, :operator, :presence => true

  after_commit :request_charge!, :on => :create

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

  def self.old
    where(self.arel_table[:updated_at].lt(self.long_timeout_duration_hours.ago))
  end

  def self.timeout!
    # timeout must be at least 24 hours to avoid the possibility of charging the user twice
    pending_result.old.update_all(:state => "errored", :reason => "timeout")
  end

  def self.pending_result
    where(self.arel_table[:state].eq("awaiting_result").or(self.arel_table[:state].eq("created")))
  end

  # only returns false if the charge request is awaiting a result and the timeout has not been reached
  def slow?
    (!awaiting_result? && !created?) || updated_at < self.class.short_timeout_duration_seconds.ago
  end

  def set_result!(result, reason)
    self.result = result
    self.reason = reason
    process_result!
  end

  private

  def self.long_timeout_duration_hours
    (Rails.application.secrets[:charge_request_long_timeout_duration_hours] || DEFAULT_LONG_TIMEOUT_DURATION_HOURS).to_i.hours
  end

  def self.short_timeout_duration_seconds
    (Rails.application.secrets[:charge_request_short_timeout_duration_hours] || DEFAULT_SHORT_TIMEOUT_DURATION_SECONDS).to_i.seconds
  end

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
    ChargeRequesterJob.perform_later(
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
