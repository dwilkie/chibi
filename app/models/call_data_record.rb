class CallDataRecord < ActiveRecord::Base
  VALID_TYPES = %w{InboundCdr OutboundCdr Chibi::Twilio::InboundCdr Chibi::Twilio::OutboundCdr}

  mount_uploader :cdr_data, CdrDataUploader

  after_initialize  :set_type
  before_validation :set_cdr_attributes, :on => :create

  include Chibi::Communicable::FromUser

  belongs_to :phone_call
  belongs_to :inbound_cdr

  validates :user, :associated => true, :presence => true
  validates :duration, :bill_sec, :uuid, :type, :direction, :presence => true
  validates :type, :inclusion => { :in => VALID_TYPES }
  validates :uuid, :uniqueness => true
  validates :phone_call_id, :uniqueness => {:scope => :type}, :allow_nil => true

  attr_accessor :body

  def typed
    VALID_TYPES.include?(type) ? type.constantize.new(:body => body) : self
  end

  private

  def set_type
    if new_record? && body.present?
      self.direction ||= variables["direction"]
      self.type ||= "#{direction}_cdr".classify
    end
  end

  def set_cdr_attributes
    if body.present?
      self.uuid ||= variables["uuid"]
      self.duration ||= variables["duration"]
      self.bill_sec ||= variables["billsec"]
      self.bridge_uuid ||= variables["bridge_uuid"]
      self.from ||= cdr_from
      self.phone_call ||= find_related_phone_call
      set_cdr_data
    end
  end

  def set_cdr_data
    self.cdr_data = Chibi::StringIO.new("#{uuid}.cdr.xml", body)
  end

  def unescaped_variable(*keys)
    options = keys.extract_options!
    raw_value = keys.unshift(options[:root] || "variables").inject(parsed_body) do |config, key|
      config[key] if config.is_a?(Hash)
    end
    Rack::Utils.unescape(raw_value).strip if raw_value
  end

  def valid_source(*keys)
    normalized_value = unescaped_variable(*keys)
    normalized_value if normalized_value =~ /\A\+?\d+\z/
  end

  def variables
    parsed_body["variables"]
  end

  def parsed_body
    return @parsed_body if @parsed_body
    MultiXml.parser = ::Chibi::MultiXml::Parsers::CdrParser
    @parsed_body = ::MultiXml.parse(body)["cdr"]
    MultiXml.parser = MultiXml.default_parser
    @parsed_body
  end
end
