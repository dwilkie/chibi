class ReportGenerator
  @queue = :report_generator_queue

  def self.perform(options = {})
    report = Report.new(HashWithIndifferentAccess.new(options))
    report.generate!
  rescue Resque::TermException
    Resque.enqueue(self, options)
  end
end
