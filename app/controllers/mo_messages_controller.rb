class MoMessagesController < ApplicationController

  http_basic_authenticate_with :name => Nuntium.incoming_user,
                               :password => Nuntium.incoming_password,
                               :only => :create

  def index
    @mo_messages = MoMessage.scoped
  end

  def create
    message = MoMessage.new(params.slice :from, :body, :guid)
    message.user = User.find_or_create_by_mobile_number(message.origin)
    message.save
    render :nothing => true
  end

end

