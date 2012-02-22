class RepliesController < ApplicationController
  def index
    replies = Reply.filter_by(params)
    @reply_count = replies.count
    @replies = replies.page params[:page]
  end
end
