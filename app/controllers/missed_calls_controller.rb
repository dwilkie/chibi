class MissedCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_cloudmailin, :only => :create
  before_filter :authenticate_admin, :except => :create

  def create
    render :nothing => true, :status => 200 # a status of 404 would reject the mail
  end

  private

  def authenticate_cloudmailin
    authenticate(ENV["HTTP_BASIC_AUTH_CLOUDMAILIN_USER"], ENV["HTTP_BASIC_AUTH_CLOUDMAILIN_PASSWORD"])
  end
end
