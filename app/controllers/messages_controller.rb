class MessagesController < ApplicationController
  def index
    @messages = Message.scoped
  end

  def create
    message = Message.new(params.slice :from, :body)
    from = message.origin
    message.user = User.find_or_initialize_by_mobile_number(from)
    message.user.build_location(:country_code => Location.country_code(from)) unless message.user.location
    if message.save
      Resque.enqueue(MessageProcessor, message.id)
      response_params = {:status => :created, :location => messages_path(message)}
    else
      response_params = {:status => :bad_request}
    end
    render({:nothing => true}.merge(response_params))
  end
end
