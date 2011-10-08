class UsersController < ApplicationController
  skip_before_filter :authenticate
  http_basic_authenticate_with :name => "chibitxt", :password => "secret"

  def index
    @user_count = User.count
    @users = User.page params[:page]
  end
end

