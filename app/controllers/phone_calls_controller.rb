class PhoneCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_phone_call, :only => :create
  before_filter :authenticate_admin, :except => :create

  def index
    phone_calls = PhoneCall.filter_by(params)
    @phone_call_count = phone_calls.count
    @phone_calls = phone_calls.page params[:page]
  end

  def create
    if phone_call = PhoneCall.find_or_create_and_process_by(params, current_authenticated_url)
      p phone_call.to_twiml
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
