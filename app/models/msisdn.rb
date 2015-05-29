class Msisdn < ActiveRecord::Base
  include AASM

  DEFAULT_BROADCAST_MAX_QUEUED = 100

  validates :mobile_number, :presence => true
  validates :state, :presence => true
  validates :operator, :presence => true
  validates :country_code, :presence => true

  aasm :column => :state do
    state :unchecked, :initial => true
    state :queued_for_checking
    state :awaiting_result
    state :active
    state :inactive
  end

  def self.by_operator(country_code, operator_id)
    where(:country_code => country_code, :operator => operator_id)
  end

  def self.foo
    return if queue_full?

    broadcast_operators.each do |country, operators|
      operators.each do |operator, operator_metadata|
        p last_generated_mobile_number = by_operator(country, operator).maximum(:mobile_number)
        #operator_metadata["mobile_prefixes"]
      end
    end
  end

  def self.queued
    where.not(:state => :active).where.not(:state => :inactive).where.not(:state => :awaiting_result)
  end

  def self.queue_full?
    queued.count >= max_queued
  end

  def self.generate_range(start_range, end_range)
  end

  def self.max_queued
    (Rails.application.secrets[:broadcast_max_queued] || DEFAULT_BROADCAST_MAX_QUEUED).to_i
  end

  def self.broadcast_operators
    @@broadcast_operators ||= set_broadcast_operators
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

  private_class_method :set_broadcast_operators
end
