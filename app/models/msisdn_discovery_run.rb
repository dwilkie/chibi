class MsisdnDiscoveryRun < ActiveRecord::Base
  DEFAULT_BROADCAST_MAX_QUEUED = 100
  DEFAULT_BROADCAST_HOURS_MIN = 8
  DEFAULT_BROADCAST_HOURS_MAX = 20

  has_many :msisdn_discoveries

  validates :operator, :country_code, :prefix,
            :presence => true

  validates :subscriber_number_min, :subscriber_number_max,
            :presence => true, :numericality => { :only_integer => true, :greater_than_or_equal_to => 0 }

  def self.by_prefix(prefix)
    where(:prefix => prefix)
  end

  def self.by_operator(country_code, operator_id)
    where(:country_code => country_code, :operator => operator_id)
  end

  def self.active
    where(:active => true)
  end

  def self.inactive
    where.not(:active => true)
  end

  def self.cleanup!
    inactive.joins(all_msisdn_discoveries).merge(MsisdnDiscovery.without_msisdn_discovery_run).delete_all
  end

  def self.all_msisdn_discoveries
    msisdn_discovery_runs = self.arel_table
    msisdn_discoveries = MsisdnDiscovery.arel_table

    join = msisdn_discovery_runs.join(
      msisdn_discoveries, Arel::Nodes::OuterJoin
    ).on(
      msisdn_discovery_runs[:id].eq(msisdn_discoveries[:msisdn_discovery_run_id])
    ).join_sources
  end

  def self.discover!
    return if out_of_broadcast_hours? || queue_full?

    deactivate!
    create_from_broadcast_operators!

    batch_size = queue_buffer

    group(:country_code, :operator).count.each do |operator, count_by_operator|
      next if !broadcast_to?(*operator)
      active_discovery_runs = by_operator(*operator).active
      discovery_batches = {}
      enqueued_discoveries = []

      while enqueued_discoveries.size < batch_size do
        random_discovery_run = active_discovery_runs.sample
        random_batch = discovery_batches[random_discovery_run.id] ||= random_discovery_run.random_batch(batch_size)

        if random_subscriber_number = random_batch.pop
          random_discovery_run.enqueue_discovery!(random_subscriber_number)
        end

        enqueued_discoveries << random_subscriber_number
      end
    end
  end

  def random_batch(batch_size)
    self.class.connection.select_all(random_batch_sql(batch_size)).rows.flatten
  end

  def finished?
    subscriber_number_range.count == msisdn_discoveries.count
  end

  def discover!(subscriber_number)
    msisdn_discovery = msisdn_discoveries.build(:subscriber_number => subscriber_number)
    msisdn_discovery.broadcast! if msisdn_discovery.save
  end

  def enqueue_discovery!(subscriber_number)
    MsisdnDiscoveryJob.perform_later(self.id, subscriber_number)
  end

  private

  def random_batch_sql(batch_size)
    [generate_series_sql, "EXCEPT", subscriber_numbers_sql, "LIMIT ", batch_size].join(" ")
  end

  def generate_series_sql
    "(SELECT generate_series(#{subscriber_number_min}, #{subscriber_number_max}))"
  end

  def subscriber_numbers_sql
    "(#{msisdn_discoveries.subscriber_numbers.to_sql})"
  end

  def subscriber_number_range
    subscriber_number_min..subscriber_number_max
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

  def self.deactivate!
    finished.update_all(:active => false)
  end

  def self.finished
    active.where(:id => active.select(&:finished?).map(&:id))
  end

  def self.create_from_broadcast_operators!
    broadcast_operators.each do |country, operators|
      operators.each do |operator, operator_metadata|
        active_operator_discovery_runs = by_operator(country, operator).active
        next if active_operator_discovery_runs.any?
        mobile_prefixes(operator_metadata).each do |prefix, prefix_metadata|
          if active_operator_discovery_runs.by_prefix(prefix).empty?
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
                       :mobile_prefixes,
                       :deactivate!,
                       :finished
end
