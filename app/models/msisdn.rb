class Msisdn < ActiveRecord::Base
  include AASM

  DEFAULT_BROADCAST_MAX_QUEUED = 100
  DEFAULT_BROADCAST_HOURS_MIN = 8
  DEFAULT_BROADCAST_HOURS_MAX = 20

  before_validation :set_operator_data, :on => :create

  has_many :replies

  validates :mobile_number, :presence => true
  validates :state, :presence => true
  validates :operator, :presence => true
  validates :country_code, :presence => true
  validates :number_of_checks, :presence => true, :numericality => {:only_integer => true, :greater_than_or_equal_to => 0}

  aasm :column => :state do
    state :unchecked, :initial => true
    state :queued_for_checking
    state :awaiting_result
    state :active
    state :inactive
  end

  def discover!
    send_discovery_reply!
    self.number_of_checks += 1
    self.last_checked_at = Time.now
    save!
  end

  def self.by_operator(country_code, operator_id)
    where(:country_code => country_code, :operator => operator_id)
  end

  def self.least_number_of_checks
    all.minimum(:number_of_checks).to_i
  end

  def self.discover!
    return if queue_full? || out_of_broadcast_hours?

    broadcast_operators.each do |country, operators|
      operators.each do |operator, operator_metadata|
        operator_scope = by_operator(country, operator)

        highest_mobile_number = operator_scope.where(
          :number_of_checks => operator_scope.least_number_of_checks
        ).maximum(:mobile_number)

        generate_mobile_range(operator_metadata, highest_mobile_number).each do |mobile_number|
          enqueue_discovery!(mobile_number)
        end
      end
    end
  end

  def self.queued
    where.not(:state => :active).where.not(:state => :inactive).where.not(:state => :awaiting_result)
  end

  def self.queue_full?
    broadcasts_in_queue >= broadcast_max_queued
  end

  def self.queue_buffer
    broadcast_max_queued - [broadcasts_in_queue, broadcast_max_queued].min
  end

  def self.broadcasts_in_queue
    queued.count
  end

  def self.out_of_broadcast_hours?
    current_hour = Time.current.hour
    current_hour < broadcast_hours_min || current_hour >= broadcast_hours_max
  end

  def self.broadcast_hours_min
    (Rails.application.secrets[:broadcast_hours_min] || DEFAULT_BROADCAST_HOURS_MIN).to_i
  end

  def self.broadcast_hours_max
    (Rails.application.secrets[:broadcast_hours_max] || DEFAULT_BROADCAST_HOURS_MAX).to_i
  end

  def self.broadcast_max_queued
    (Rails.application.secrets[:broadcast_max_queued] || DEFAULT_BROADCAST_MAX_QUEUED).to_i
  end

  def self.broadcast_operators
    @@broadcast_operators ||= set_broadcast_operators
  end

  private

  def send_discovery_reply!
    replies.build(:to => mobile_number).broadcast!(country_code)
  end

  def set_operator_data
    self.country_code ||= torasup_number.country_id
    self.operator ||= torasup_number.operator.id
  end

  def torasup_number
    @torasup_number ||= Torasup::PhoneNumber.new(mobile_number)
  end

  def self.generate_mobile_range(operator_metadata, highest_mobile_number)
    next_prefix = nil
    range_metadata = nil
    next_subscriber_number = nil
    while(!next_subscriber_number)
      mobile_prefixes = operator_metadata["mobile_prefixes"].sort.to_h
      mobile_prefixes.each do |prefix, prefix_metadata|
        next_prefix = prefix
        range_metadata = prefix_metadata
        next_subscriber_number = prefix_metadata["subscriber_number_min"] if !highest_mobile_number
        break if !!next_subscriber_number
        next if !highest_mobile_number.start_with?(prefix)
        highest_subscriber_number = highest_mobile_number.gsub(/^#{prefix}/, "")
        proposed_next_subscriber_number = (highest_subscriber_number.to_i + 1)
        next if proposed_next_subscriber_number > prefix_metadata["subscriber_number_max"]
        next_subscriber_number = proposed_next_subscriber_number
      end
    end
    range_min = next_prefix + next_subscriber_number.to_s
    proposed_max_subscriber_number = next_subscriber_number + queue_buffer
    max_subscriber_number = proposed_max_subscriber_number > range_metadata["subscriber_number_max"] ?
      range_metadata["subscriber_number_max"] : proposed_max_subscriber_number
    range_max = next_prefix + max_subscriber_number.to_s
    (range_min..range_max)
  end

  def self.set_broadcast_operators
    broadcast_operators = Torasup::Operator.registered.dup
    broadcast_operators.each do |country, operators|
      operators.each do |operator, operator_metadata|
        operators.delete(operator) if (ENV["broadcast_to_#{country}_#{operator}".upcase] || 1).to_i.zero?
      end
    end
    broadcast_operators
  end

  def self.enqueue_discovery!(mobile_number)
    MsisdnDiscoveryJob.perform_later(mobile_number)
  end

  private_class_method :set_broadcast_operators, :generate_mobile_range, :enqueue_discovery!
end
