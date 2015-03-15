class TestMessagesController < ApplicationController
  before_filter :authenticate_admin

  def new
    @message = Message.new
  end

  def create
    @message = Message.new(permitted_params)
    @message.channel = "test_messages"
    if @message.save
      @message.process!
      redirect_to users_path
    else
      render :new
    end
  end

  private

  def permitted_params
    params.require(:message).permit(:from, :body)
  end
end
