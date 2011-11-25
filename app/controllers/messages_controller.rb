class MessagesController < ApplicationController
  def index
    @messages = Message.scoped
  end

  def create
    message = Message.new(params.slice :from, :body)
    from = message.origin
    message.user = User.find_or_initialize_by_mobile_number(from)
    unless user.location_id?
      location = user.message.build_location
      location.country_code = Location.country_code(from)
    end 
    message.save!
    message.process! # move this into a background process
    render :nothing => true, :status => :created, :location => messages_path(message)
  end
end

