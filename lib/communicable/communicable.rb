module Communicable
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

  module HasChatableResources
    extend ActiveSupport::Concern

    included do
      has_many :messages
      has_many :replies
      has_many :phone_calls
    end

    module ClassMethods
      def filter_by(params = {})
        chatable_resources_scope
      end

      def filter_by_count(params = {})
        filter_params(params).count
      end

      def find_with_chatable_resources_counts(id)
        result = chatable_resources_scope.where(:id => id).first
        raise ActiveRecord::RecordNotFound unless result.present?
        result
      end

      private

      def chatable_resources_scope
        joins_column_name = "#{table_name.singularize}_id"

        scoped.select(
          "#{table_name}.*,
          COUNT(DISTINCT(messages.id)) AS messages_count,
          COUNT(DISTINCT(replies.id)) AS replies_count,
          COUNT(DISTINCT(phone_calls.id)) AS phone_calls_count",
        ).joins(
          "LEFT OUTER JOIN messages ON messages.#{joins_column_name} = #{table_name}.id"
        ).joins(
          "LEFT OUTER JOIN replies ON replies.#{joins_column_name} = #{table_name}.id"
        ).joins(
          "LEFT OUTER JOIN phone_calls ON phone_calls.#{joins_column_name} = #{table_name}.id"
        ).group(all_columns).order(
          "#{table_name}.created_at DESC"
        )
      end

      def filter_params(params = {})
        scoped
      end
    end
  end
end
