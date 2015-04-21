class PhoneCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_phone_call

  def create
    @phone_call = PhoneCall.answer!(permitted_params, current_authenticated_url)
    render_phone_call
  end

  def show
    find_and_initialize_phone_call
    render_phone_call
  end

  def update
    find_and_initialize_phone_call
    @phone_call.flag_as_processing!
    render_phone_call
  end

  private

  def find_and_initialize_phone_call
    find_phone_call
    @phone_call.set_call_params(permitted_params, current_authenticated_url)
  end

  def find_phone_call
    @phone_call = PhoneCall.find(permitted_params[:id])
  end

  def permitted_params
    params.permit!
  end

  def render_phone_call
    respond_to do |format|
      format.xml { render :xml => @phone_call.to_twiml }
    end
  end

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
