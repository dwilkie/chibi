class MsisdnDiscoveryRun < ActiveRecord::Base
  DEFAULT_BROADCAST_MAX_QUEUED = 100
  DEFAULT_BROADCAST_HOURS_MIN = 8
  DEFAULT_BROADCAST_HOURS_MAX = 20

  has_many :msisdn_discoveries

  validates :operator, :country_code, :prefix,
            :presence => true

  validates :subscriber_number_min, :subscriber_number_max,
            :presence => true, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0 }

  delegate :highest_discovered_subscriber_number, :to => :msisdn_discoveries

  def self.by_prefix(prefix)
    where(:prefix => prefix)
  end

  def self.by_operator(country_code, operator_id)
    where(:country_code => country_code, :operator => operator_id)
  end

  def self.discover!
    return if out_of_broadcast_hours? || queue_full?
    create_from_broadcast_operators!

    batch_size = queue_buffer
    group(:country_code, :operator).count.each do |operator, count_by_operator|
      next if !broadcast_to?(*operator)
      operator_scope = by_operator(*operator)
      operator_scope.group(:prefix).count.sort_by {|k, v| [v, k]}.to_h.each do |prefix, count_by_prefix|
        if mobile_prefixes((broadcast_operators[operator[0]] || {})[operator[1]]).has_key?(prefix)
          operator_scope.by_prefix(prefix).last!.discover_batch!(batch_size)
          break
        end
      end
    end
  end

  def discover_batch!(batch_size)
    subscriber_number_start = highest_discovered_subscriber_number ? highest_discovered_subscriber_number + 1 : subscriber_number_min
    msisdn_discovery_start = msisdn_discoveries.build(
      :subscriber_number => subscriber_number_start
    )
    msisdn_discovery_end = msisdn_discoveries.build(
      :subscriber_number => msisdn_discovery_start.subscriber_number + batch_size - 1
    )

    msisdn_discovery_end.subscriber_number = subscriber_number_max if !msisdn_discovery_end.valid?

    (msisdn_discovery_start.subscriber_number..msisdn_discovery_end.subscriber_number).each do |subscriber_number|
      enqueue_discovery!(subscriber_number)
    end
  end

  def finished?
    highest_discovered_subscriber_number == subscriber_number_max
  end

  def discover!(subscriber_number)
    msisdn_discovery = msisdn_discoveries.build(:subscriber_number => subscriber_number)
    msisdn_discovery.broadcast! if msisdn_discovery.save
  end

  private

  def enqueue_discovery!(subscriber_number)
    MsisdnDiscoveryJob.perform_later(self.id, subscriber_number)
  end

  def self.broadcasts_in_queue
    MsisdnDiscovery.queued.count
  end

  def self.queue_full?
    broadcasts_in_queue >= broadcast_max_queued
  end

  def self.queue_buffer
    (broadcast_max_queued - [broadcasts_in_queue, broadcast_max_queued].min) / number_of_broadcast_operators
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
    @broadcast_operators || set_broadcast_operators
    @broadcast_operators
  end

  def self.number_of_broadcast_operators
    @number_of_broadcast_operators || set_broadcast_operators
    @number_of_broadcast_operators
  end

  def self.mobile_prefixes(operator_metadata = {})
    operator_metadata["mobile_prefixes"]
  end

  def self.create_from_broadcast_operators!
    broadcast_operators.each do |country, operators|
      operators.each do |operator, operator_metadata|
        mobile_prefixes(operator_metadata).each do |prefix, prefix_metadata|
          discovery_run = by_operator(country, operator).by_prefix(prefix).last
          if !discovery_run || discovery_run.finished?
            create!(
              :country_code => country,
              :operator => operator,
              :prefix => prefix,
              :subscriber_number_min => prefix_metadata["subscriber_number_min"],
              :subscriber_number_max => prefix_metadata["subscriber_number_max"]
            )
          end
        end
      end
    end
  end

  def self.registered_operators
    @registered_operators ||= Torasup::Operator.registered
  end

  def self.registered_operator(country, operator)
    ((registered_operators[country] || {})[operator] || {})
  end

  def self.set_broadcast_operators
    @broadcast_operators = registered_operators.dup
    @number_of_broadcast_operators = 0
    @broadcast_operators.each do |country, operators|
      operators.each do |operator, operator_metadata|
        !broadcast_to?(country, operator) ? operators.delete(operator) : @number_of_broadcast_operators += 1
      end
    end
  end

  def self.broadcast_to?(country, operator)
    !!registered_operator(country, operator)["smpp_server_id"] && !(ENV["broadcast_to_#{country}_#{operator}".upcase] || 1).to_i.zero?
  end

  private_class_method :set_broadcast_operators,
                       :create_from_broadcast_operators!,
                       :mobile_prefixes
end
