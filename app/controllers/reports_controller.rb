class ReportsController < ApplicationController
  before_filter :authenticate_admin

  def create
    Report.clear
    Resque.enqueue(ReportGenerator, params[:report])
    redirect_to report_path
  end

  def show
    send_data(Report.data, :filename => Report.filename, :type => Report.type) if Report.generated?
  end
end
