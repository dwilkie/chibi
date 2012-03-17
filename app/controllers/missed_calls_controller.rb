class MissedCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_cloudmailin, :only => :create
  before_filter :authenticate_admin, :except => :create

  def create
    missed_call = MissedCall.new(params.slice(:subject))
    if missed_call.save
      Resque.enqueue(Dialer, missed_call.id, phone_calls_url)
      status = :ok
    else
      status = :bad_request
    end
    render :nothing => true, :status => status
  end

  private

  def authenticate_cloudmailin
    authenticate(ENV["HTTP_BASIC_AUTH_CLOUDMAILIN_USER"], ENV["HTTP_BASIC_AUTH_CLOUDMAILIN_PASSWORD"])
  end
end
