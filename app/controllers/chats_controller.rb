class ChatsController < ApplicationController
  def index
    chats = Chat.filter_by(params)
    @chat_count = chats.count
    @chats = chats.page params[:page]
  end
end
