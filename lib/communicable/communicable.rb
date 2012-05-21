module Communicable
  extend ActiveSupport::Concern

  module ClassMethods
    def users_latest
      association_reflection = reflect_on_association(:user)

      select(
        "\"#{table_name}\".\"created_at\""
      ).where(
        "\"#{table_name}\".\"#{association_reflection.foreign_key}\" = \"#{association_reflection.klass.table_name}\".\"id\""
      ).order(
        "\"#{table_name}\".\"created_at\" DESC"
      ).limit(1)
    end
  end

  module FromUser
    extend ActiveSupport::Concern

    included do
      attr_accessible :from

      belongs_to :user, :touch => true

      validates :user, :associated => true, :presence => true
      validates :from, :presence => true

      after_initialize :assign_to_user
    end

    def from=(value)
      write_attribute(:from, value.gsub(/\D/, "")) if value
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

    COMMUNICABLE_RESOURCES = [:messages, :replies, :phone_calls]

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

      def find_with_communicable_resources_counts(id)
        result = communicable_resources_scope.where(:id => id).first
        raise ActiveRecord::RecordNotFound unless result.present?
        result
      end

      def filter_params(params = {})
        scoped
      end

      private

      def communicable_resources_scope
        joins_column_name = "#{table_name.singularize}_id"

        select_values = ["#{table_name}.*"]
        joins_values = []

        COMMUNICABLE_RESOURCES.each do |communicable_resource|
          select_values << "COUNT(DISTINCT(#{communicable_resource}.id)) AS #{communicable_resource}_count"
          joins_values << "LEFT OUTER JOIN #{communicable_resource} ON #{communicable_resource}.#{joins_column_name} = #{table_name}.id"
        end

        scoped.select(select_values.join(", ")).joins(joins_values.join(" ")).group(all_columns).order(
          "#{table_name}.created_at DESC"
        )
      end
    end
  end
end
