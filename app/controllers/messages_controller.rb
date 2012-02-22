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
    message = Message.new(params.slice(:from, :body))
    from = message.origin
    message.user = User.find_or_initialize_by_mobile_number(from)
    message.user.build_location(:country_code => Location.country_code(from)) unless message.user.location
    if message.save
      Resque.enqueue(MessageProcessor, message.id)
      response_params = {:status => :created}
    else
      response_params = {:status => :bad_request}
    end
    render({:nothing => true}.merge(response_params))
  end
end
