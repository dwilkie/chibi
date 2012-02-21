class RepliesController < ApplicationController
  before_filter :authenticate_admin

  def index
    replies = Reply.filter_by(params)
    @reply_count = replies.count
    @replies = replies.page params[:page]
  end
end
