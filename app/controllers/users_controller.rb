class UsersController < ApplicationController
  before_filter :authenticate_admin

  def index
    @user_count = User.count
    @users = User.order(:created_at).page params[:page]
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to :action => :index
  end
end
