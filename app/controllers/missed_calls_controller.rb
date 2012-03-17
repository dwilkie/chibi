class MissedCallsController < ApplicationController
  require 'mail'
  protect_from_forgery :except => :create

  before_filter :authenticate_mailin, :only => :create
  before_filter :authenticate_admin, :except => :create

  def create
    message = Mail.new(params[:message])
    Rails.logger.log Logger::INFO, message.subject #print the subject to the logs
    Rails.logger.log Logger::INFO, message.body.decoded #print the decoded body to the logs

    # Do some other stuff with the mail message

    render :nothing => true, :status => 200 # a status of 404 would reject the mail
  end

  private

  def authenticate_mailin
    authenticate(ENV["HTTP_BASIC_AUTH_MAILIN_USER"], ENV["HTTP_BASIC_AUTH_MAILIN_PASSWORD"])
  end
end
