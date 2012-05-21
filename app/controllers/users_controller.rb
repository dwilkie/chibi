class UsersController < ApplicationController
  before_filter :authenticate_admin

  def index
    @user_overview = UserOverview.new(params)
  end

  def show
    @user = User.find_with_communicable_resources_counts(params[:id])
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to :action => :index
  end
end
