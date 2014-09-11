class InteractionsController < ApplicationController
  before_filter :authenticate_admin

  def show
    @interaction = Interaction.new(permitted_params)
  end

  private

  def permitted_params
    params.permit(:user_id, :chat_id)
  end
end
