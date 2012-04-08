class ChatsController < ApplicationController
  before_filter :authenticate_admin

  def index
    chats = Chat.filter_by(params)
    @chat_count = Chat.filter_by_count(params)
    @chats = chats.page params[:page]
  end
end
