class MissedCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_missed_call

  def create
    missed_call = MissedCall.new(missed_call_params.slice(:subject, :plain))
    if missed_call.save
      Resque.enqueue(Dialer, missed_call.id)
      status = :ok
    else
      status = :bad_request
    end
    render :nothing => true, :status => status
  end

  private

  def authenticate_missed_call
    authenticate(:missed_call)
  end

  def missed_call_params
    params.permit(:subject, :plain)
  end
end
