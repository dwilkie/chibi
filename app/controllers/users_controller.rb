class UsersController < ApplicationController
  before_filter :authenticate_admin

  def index
    @user_count = User.count
    @users = User.page params[:page]
  end
end
