class ReportsController < ApplicationController
  before_filter :authenticate_admin

  def create
    Resque.enqueue(ReportGenerator, params[:report])
    redirect_to overview_path, :notice => "Generating report. Check your email"
  end
end
