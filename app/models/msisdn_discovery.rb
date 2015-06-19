class MsisdnDiscovery < ActiveRecord::Base
  belongs_to :msisdn_discovery_run
  belongs_to :msisdn
  has_one    :reply

  before_validation :set_msisdn, :on => :create

  delegate :prefix,
           :subscriber_number_min,
           :subscriber_number_max,
           :country_code,
           :to => :msisdn_discovery_run,
           :allow_nil => true

  delegate :mobile_number, :blacklisted?, :to => :msisdn
  delegate :activate!, :deactivate!, :to => :msisdn, :prefix => true

  delegate :queued_for_smsc_delivery?,
           :delivered_by_smsc?,
           :confirmed?,
           :delivered?,
           :to => :reply,
           :prefix => true

  validates :msisdn_discovery_run,
            :msisdn,
            :state,
            :presence => true

  validates :subscriber_number, :presence => true,
            :numericality => {
              :only_integer => true,
              :greater_than_or_equal_to => proc { |m| m.subscriber_number_min.to_i },
              :less_than_or_equal_to => proc { |m| m.subscriber_number_max.to_i }
            }

  validates :msisdn_id, :uniqueness => { :scope => [:msisdn_discovery_run_id] }

  include AASM

  aasm :column => :state do
    state :not_started, :initial => true
    state :skipped
    state :queued_for_discovery
    state :awaiting_result
    state :inactive
    state :active

    event :skip do
      transitions(
        :from   => :not_started,
        :to     => :skipped,
      )
    end

    event :queue_for_discovery do
      transitions(
        :from   => [:not_started, :queued_for_discovery],
        :to     => :queued_for_discovery,
      )
    end

    event :await_result do
      transitions(
        :from   => :queued_for_discovery,
        :to     => :awaiting_result,
      )
    end

    event :activate, :after_commit => :msisdn_activate! do
      transitions(:to => :active)
    end

    event :deactivate, :after_commit => :msisdn_deactivate! do
      transitions(:to => :inactive)
    end
  end

  def self.queued
    where(:state => [:not_started, :queued_for_discovery])
  end

  def self.queued_too_long
    queued.where(self.arel_table[:created_at].lt(1.day.ago))
  end

  def self.highest_discovered_subscriber_number
    maximum(:subscriber_number)
  end

  def self.all_replies
    msisdn_discoveries = self.arel_table
    replies = Reply.arel_table

    join = msisdn_discoveries.join(
      replies, Arel::Nodes::OuterJoin
    ).on(
      msisdn_discoveries[:id].eq(replies[:msisdn_discovery_id])
    ).join_sources
  end

  def self.with_outdated_state
    queued_too_long.joins(:reply).merge(Reply.accepted_by_smsc)
  end

  def self.with_missing_broadcast
    queued_too_long.joins(all_replies).merge(Reply.not_a_msisdn_discovery)
  end

  def self.cleanup_queued!
    with_missing_broadcast.find_each { |msisdn_discovery| msisdn_discovery.broadcast! }
    with_outdated_state.find_each    { |msisdn_discovery| msisdn_discovery.notify     }
  end

  def notify
    return if !reply_delivered?
    if reply_queued_for_smsc_delivery?
      queue_for_discovery!
    elsif reply_delivered_by_smsc?
      await_result!
    elsif reply_confirmed?
      activate!
    else
      deactivate!
    end
  end

  def broadcast!
    skip_broadcast? ? skip! : build_reply(:to => mobile_number).broadcast!(:locale => country_code)
  end

  private

  def skip_broadcast?
    blacklisted?
  end

  def set_msisdn
    self.msisdn = Msisdn.where(:mobile_number => number_to_discover).first_or_initialize
  end

  def number_to_discover
    prefix.to_s + subscriber_number.to_s
  end
end
