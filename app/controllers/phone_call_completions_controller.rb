class PhoneCallCompletionsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_phone_call

  def create
    PhoneCallCompletionJob.perform_later(params)
    render(:nothing => true)
  end

  private

  def authenticate_phone_call
    authenticate(:phone_call)
  end
end
