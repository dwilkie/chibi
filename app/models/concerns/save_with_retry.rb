module SaveWithRetry
  extend ActiveSupport::Concern

  DEFAULT_MAX_TRIES = 5

  module ClassMethods
    def save_with_retry!(&block)
      begin
        yield
      rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
        save_with_retry_count ||= 0
        save_with_retry_count += 1
        retry if (save_with_retry_count < save_with_retry_max_tries)
        raise(error)
      end
    end

    def save_with_retry_max_tries
      Rails.application.secrets[:save_with_retry_max_tries] || DEFAULT_MAX_TRIES
    end
  end
end
