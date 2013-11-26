module Chibi
  module Communicable
    extend ActiveSupport::Concern

    included do
      belongs_to :user, :touch => :last_contacted_at
      validates :user, :associated => true, :presence => true
    end

    module FromUser
      extend ActiveSupport::Concern
      include Chibi::Twilio::ApiHelpers

      # the maximum length of a US phone number
      # without the country code
      # note: this is only used to determine whether Twilio added an extra 1 or not
      MAX_LOCAL_NUMBER_LENGTH = 10
      MIN_LOCAL_NUMBER_LENGTH = 8

      included do
        before_validation :assign_to_user, :on => :create
        after_create :record_user_interaction

        validates :from, :presence => true
      end

      def from=(value)
        # this method is overriden because Twilio adds
        # random 1's to the start of phone numbers

        return write_attribute(:from, value) if value.blank?

        # remove any non-digits and leading 0's to produce a more valid looking E.164 number
        sanitized_value = value.gsub(/\D/, "").gsub(/\A0+/, "")

        number_with_country_code = Phony.normalize(sanitized_value)
        # don't do anything if it's a twilio number or it's too short
        return if twilio_number?(number_with_country_code, :formatted => false) || sanitized_value.length < MIN_LOCAL_NUMBER_LENGTH

        # if the number is plausible now write it to from
        number_with_country_code = Phony.normalize(sanitized_value)
        return write_from(number_with_country_code) if number_with_country_code.length >= User::MINIMUM_MOBILE_NUMBER_LENGTH && Phony.plausible?(number_with_country_code)

        # assume it's a local number with the incorrect US country code added
        # Twilio does this sometimes
        local_number = sanitized_value.gsub(/\A1{1}/, "")
        number_with_country_code = Phony.normalize(ENV['DEFAULT_COUNTRY_CODE'] + local_number)
        return write_from(number_with_country_code) if Phony.plausible?(number_with_country_code)

        # assume it's a normal local number
        number_with_country_code = Phony.normalize(ENV['DEFAULT_COUNTRY_CODE'] + sanitized_value)
        return write_from(number_with_country_code) if Phony.plausible?(number_with_country_code)

        # assume it's in internaltional number with the incorrect US country code added
        # Twilio does this sometimes
        non_us_number = sanitized_value.gsub(/\A1+/, "")
        sanitized_value = non_us_number if non_us_number.length > MAX_LOCAL_NUMBER_LENGTH
        write_from(sanitized_value)
      end

      private

      def write_from(value)
        write_attribute(:from, value)
      end

      def record_user_interaction
        user.touch(:last_interacted_at) if self.class.user_interaction?
      end

      def assign_to_user
        self.user = User.find_or_initialize_by(:mobile_number => from) unless user_id.present?
      end

      module ClassMethods
        def user_interaction?
          true
        end
      end
    end

    module Chatable
      extend ActiveSupport::Concern

      included do
        belongs_to :chat, :touch => true
      end

      module ClassMethods
        def filter_by(params = {})
          where(params.slice(:user_id, :chat_id)).order("created_at DESC")
        end
      end
    end

    module HasCommunicableResources
      extend ActiveSupport::Concern

      included do
        cattr_accessor :communicable_resources
      end

      module ClassMethods
        def has_communicable_resources(*resources)
          self.communicable_resources ||= []

          resources.each do |resources_config|
            if resources_config.is_a?(Hash)
              resources_name = resources_config.keys.first
              resources_options = resources_config[resources_name]
            else
              resources_name = resources_config
              resources_options = {}
            end

            association_options = ""
            resources_options.each do |key, value|
              association_options += ", :#{key} => #{value}"
            end
            self.instance_eval <<-RUBY, __FILE__, __LINE__+1
              has_many :#{resources_name}#{association_options}
            RUBY

            self.communicable_resources << resources_name
          end
        end

        def filter_by(params = {})
          communicable_resources_scope.filter_params(params)
        end

        def filter_by_count(params = {})
          filter_params(params).count
        end

        def find_with_communicable_resources(id)
          result = communicable_resources_scope.where(:id => id).first
          raise ActiveRecord::RecordNotFound unless result.present?
          result
        end

        def filter_params(params = {})
          all
        end

        private

        def communicable_resources_scope
          includes(*communicable_resources).order("\"#{table_name}\".\"updated_at\" DESC")
        end
      end
    end
  end
end
