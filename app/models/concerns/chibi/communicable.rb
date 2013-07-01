module Chibi
  module Communicable
    extend ActiveSupport::Concern

    included do
      belongs_to :user, :touch => true
      validates :user, :associated => true, :presence => true
    end

    module FromUser
      extend ActiveSupport::Concern
      include Chibi::Twilio::ApiHelpers

      # the maximum length of a US phone number
      # without the country code
      # note: this is only used to determine whether Twilio added an extra 1 or not
      MAX_LOCAL_NUMBER_LENGTH = 10

      included do
        validates :from, :presence => true

        before_validation(:on => :create) do
          assign_to_user
        end
      end

      def from=(value)
        # this method is overriden because Twilio adds
        # random 1's to the start of phone numbers
        if value.present?
          # remove any non-digits then replace multiple leading ones
          # to produce a more valid looking E.164 number
          sanitized_value = value.gsub(/\D/, "").gsub(/\A1+/, "1")
          sanitized_value = Phony.normalize(sanitized_value)

          if !twilio_number?(sanitized_value, :formatted => false) && sanitized_value.length >= User::MINIMUM_MOBILE_NUMBER_LENGTH
            # remove non digits
            if sanitized_value.first == "1"
              # remove all leading ones
              non_us_number = sanitized_value.gsub(/\A1+/, "")

              # add the default country code if the number is an invalid US Number
              sanitized_value = Phony.normalize(
                ENV['DEFAULT_COUNTRY_CODE'] + non_us_number
              ) unless Phony.plausible?(sanitized_value)

              # if the non-us number is too long
              # then assume it's an international number with the country code already included
              sanitized_value = non_us_number if non_us_number.length > MAX_LOCAL_NUMBER_LENGTH
            end
            write_attribute(:from, sanitized_value)
          end
        else
          write_attribute(:from, value)
        end
      end

      private

      def assign_to_user
        self.user = User.find_or_initialize_by(:mobile_number => from) unless user_id.present?
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

      ACTIVE_COMMUNICABLE_RESOURCES = [:phone_calls, :messages]
      COMMUNICABLE_RESOURCES = ACTIVE_COMMUNICABLE_RESOURCES + [:replies]

      included do
        COMMUNICABLE_RESOURCES.each do |communicable_resource|
          has_many communicable_resource
        end
      end

      module ClassMethods
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
          includes(*COMMUNICABLE_RESOURCES).order("\"#{table_name}\".\"updated_at\" DESC")
        end
      end
    end
  end
end
