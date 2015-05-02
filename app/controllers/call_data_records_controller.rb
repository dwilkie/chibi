class CallDataRecordsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_call_data_record

  def create
    cdr = CallDataRecord.new(:body => params["cdr"])
    cdr.typed.save!
    render :nothing => true, :status => :created
  end

  private

  def authenticate_call_data_record
    authenticate(:call_data_record)
  end
end
