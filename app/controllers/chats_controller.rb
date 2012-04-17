class ChatsController < ApplicationController
  before_filter :authenticate_admin

  def index
    @chat_count = Chat.filter_by_count(params)
    @chats = Chat.filter_by(params).page params[:page]
  end
end
