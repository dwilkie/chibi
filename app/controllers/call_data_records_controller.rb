class CallDataRecordsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_call_data_record

  def create
    CallDataRecordCreatorJob.perform_later(params["cdr"])
    render :nothing => true, :status => :created
  end

  private

  def authenticate_call_data_record
    authenticate(:call_data_record)
  end
end
