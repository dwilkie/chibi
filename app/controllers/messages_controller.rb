class MessagesController < ApplicationController
  protect_from_forgery :except => :create

  skip_before_filter :authenticate_admin, :only => :create
  before_filter :authenticate_api, :only => :create

  def index
    messages = Message.filter_by(params)
    @message_count = messages.count
    @messages = messages.page params[:page]
  end

  def create
    message = Message.new(params[:message].slice(:from, :body))
    if message.save
      Resque.enqueue(MessageProcessor, message.id)
      status = :created
    else
      status = :bad_request
    end
    render(:nothing => true, :status => status)
  end
end
