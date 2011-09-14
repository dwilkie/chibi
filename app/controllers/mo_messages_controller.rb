class MoMessagesController < ApplicationController
  http_basic_authenticate_with :name => Nuntium.incoming_user, :password => Nuntium.incoming_password, :only => :create

  def index
    @mo_messages = MoMessage.scoped
  end

  def create
    MoMessage.create(params.slice :from, :body, :guid)
    render :nothing => true
  end

end

