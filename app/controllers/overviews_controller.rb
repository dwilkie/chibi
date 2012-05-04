class OverviewsController < ApplicationController
  before_filter :authenticate_admin

  def show
    @overview = Overview.new
  end
end
