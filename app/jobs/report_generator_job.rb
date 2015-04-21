class ReportGeneratorJob < ActiveJob::Base
  queue_as Rails.application.secrets[:report_generator_queue]

  def perform(options)
    Report.new(options).generate!
  end
end
