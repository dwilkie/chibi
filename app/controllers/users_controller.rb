class UsersController < ApplicationController
  before_filter :authenticate_admin

  def index
    @user_count = User.filter_by_count(params)
    @users = User.filter_by(params).page params[:page]
  end

  def show
    @user = User.find_with_communicable_resources(params[:id])
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to :action => :index
  end
end
