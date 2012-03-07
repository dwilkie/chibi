class PhoneCallsController < ApplicationController
  protect_from_forgery :except => :create

  before_filter :authenticate_api, :only => :create
  before_filter :authenticate_admin, :except => :create

  def create
  end
end
