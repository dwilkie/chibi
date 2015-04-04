class MessagePart < ActiveRecord::Base
  belongs_to :message

  before_validation :normalize_body, :on => :create

  validates :body, :sequence_number, :presence => true

  after_commit :queue_for_processing, :on => :create

  delegate :awaiting_parts?,
           :stop_awaiting_parts,
           :find_csms_message,
           :to => :message

  def process!
    if belongs_to_another_message?
      if other_message = find_csms_message
        other_message.message_parts << self
        other_message.save!
        other_message.queue_for_processing!
      else
        stop_awaiting_parts || queue_for_processing
      end
    end
  end

  private

  def belongs_to_another_message?
    awaiting_parts? && sequence_number > 1
  end

  def queue_for_processing
    if belongs_to_another_message?
      MessagePartProcessorJob.set(:wait => message_part_processor_delay.seconds).perform_later(id)
    end
  end

  def message_part_processor_delay
    (Rails.application.secrets[:message_part_processor_delay] || 5).to_i
  end

  def normalize_body
    self.body = body.gsub("\u0000", "") if body?
  end
end
