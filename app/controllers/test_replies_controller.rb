class TestRepliesController < ApplicationController
  before_filter :authenticate_admin

  def new
    @reply = Message.new
  end

  def create
    @reply = Reply.new(permitted_params)
    if @reply.save
      @reply.deliver!
      redirect_to new_test_reply_path
    else
      render :new
    end
  end

  private

  def permitted_params
    params.require(:message).permit(:to, :body)
  end
end
