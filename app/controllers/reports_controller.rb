class ReportsController < ApplicationController
  protect_from_forgery :except => [:create, :show, :destroy]
  before_action :authenticate_admin

  def create
    if report.valid?
      report.clear
      ReportGeneratorJob.perform_later(permitted_params[:report])
    end

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
        send_data(report.data, :filename => report.filename, :type => report.type) if report.generated?
      end

      format.json do
        report.generated? ? render(:json => report.data) : render(:nothing => true, :status => :not_found)
      end
    end
  end

  def destroy
    report.clear
    respond_to do |format|
      format.json do
        render(:nothing => true, :status => :ok)
      end
    end
  end

  private

  def report
    @report ||= Report.new(permitted_params[:report])
  end

  def permitted_params
    params.permit(:report => [:year, :month])
  end
end
