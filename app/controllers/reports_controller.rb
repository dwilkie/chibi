class ReportsController < ApplicationController
  before_filter :authenticate_admin

  def create
    report = Report.new(permitted_params)
    Resque.enqueue(ReportGenerator, permitted_params) if report.valid?

    respond_to do |format|
      format.html { redirect_to(report_path) }
      format.json do
        render(:nothing => true, :status => report.valid? ? :created : :bad_request)
      end
    end
  end

  def show
    respond_to do |format|
      format.html do
        send_data(Report.data, :filename => Report.filename, :type => Report.type) if Report.generated?
      end

      format.json do
        Report.generated? ? render(:json => Report.data) : render(:nothing => true, :status => :not_found)
      end
    end
  end

  private

  def permitted_params
    params.require(:report).permit(:year, :month)
  end
end
