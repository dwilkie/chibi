module Communicable
  extend ActiveSupport::Concern

  included do
    belongs_to :user, :touch => true
    validates :user, :associated => true, :presence => true
  end

  module FromUser
    extend ActiveSupport::Concern

    included do
      attr_accessible :from

      validates :from, :presence => true

      before_validation(:on => :create) do
        assign_to_user
      end
    end

    def from=(value)
      # remove any non-digits then replace multiple leading ones
      # to produce a more valid looking E.164 number
      write_attribute(:from, value.gsub(/\D/, "").gsub(/\A1+/, "1")) if value
    end

    private

    def assign_to_user
      self.user = User.find_or_initialize_by_mobile_number(from) unless user_id.present?
    end
  end

  module Chatable
    extend ActiveSupport::Concern

    included do
      belongs_to :chat, :touch => true
    end

    module ClassMethods
      def filter_by(params = {})
        scoped.where(params.slice(:user_id, :chat_id)).order("created_at DESC")
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
        scoped
      end

      private

      def communicable_resources_scope
        scoped.includes(*COMMUNICABLE_RESOURCES).order("\"#{table_name}\".\"updated_at\" DESC")
      end
    end
  end
end
