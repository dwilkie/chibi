class ReportGeneratorJob < ActiveJob::Base
  queue_as :high

  def perform(options)
    Report.new(options).generate!
  end
end
