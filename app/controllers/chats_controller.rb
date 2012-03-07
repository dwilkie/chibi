class ChatsController < ApplicationController
  before_filter :authenticate_admin

  def index
    chats = Chat.filter_by(params)
    @chat_count = chats.count
    @chats = chats.page params[:page]
  end
end
