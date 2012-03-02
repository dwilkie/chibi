class UsersController < ApplicationController
  def index
    @user_count = User.count
    @users = User.filter_by(params).page params[:page]
  end

  def show
    @user = User.find(params[:id])
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to :action => :index
  end
end
