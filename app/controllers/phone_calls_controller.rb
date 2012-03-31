class PhoneCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_phone_call, :only => :create
  before_filter :authenticate_admin, :except => :create

  def create
    params.underscorify_keys!

    phone_call = PhoneCall.find_or_initialize_by_sid(params[:call_sid], params.slice(:from, :to))
    if phone_call.save
      phone_call.redirect_url = current_authenticated_url
      phone_call.digits = params[:digits]
      phone_call.call_status = params[:call_status]
      phone_call.dial_status = params[:dial_call_status]
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

  def current_authenticated_url
    url = URI.parse(request.url)
    user, password = ActionController::HttpAuthentication::Basic::user_name_and_password(request)
    url.user = user
    url.password = password
    url.to_s
  end

end
