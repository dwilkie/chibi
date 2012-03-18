class PhoneCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_phone_call, :only => :create
  before_filter :authenticate_admin, :except => :create

  def create
    params.underscorify_keys!

    phone_call = PhoneCall.find_or_initialize_by_sid(params[:call_sid], params.slice(:from, :to))
    if phone_call.save
      phone_call.redirect_url = request.url
      phone_call.digits = params[:digits]
      phone_call.process!
      respond_to do |format|
        format.xml { render :xml => phone_call.to_twiml }
      end
    else
      render(:nothing => true, :status => :bad_request)
    end
  end

  private

  def authenticate_phone_call
    authenticate(:phone_call)
  end
end
