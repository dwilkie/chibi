class TestRepliesController < ApplicationController
  before_filter :authenticate_admin

  def new
    @reply = Reply.new
  end

  def create
    @reply = Reply.new(permitted_params)
    @reply.user = User.find_by_mobile_number(@reply.to)
    if @reply.save
      @reply.deliver!
      redirect_to new_test_reply_path
    else
      render :new
    end
  end

  private

  def permitted_params
    params.require(:reply).permit(:to, :body)
  end
end
