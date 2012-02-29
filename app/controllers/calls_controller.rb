class CallsController < ApplicationController
  protect_from_forgery :except => :create
  skip_before_filter :authenticate_admin, :only => :create

  def create
  end
end
