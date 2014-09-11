class InteractionsController < ApplicationController
  before_filter :authenticate_admin

  def show
    @interaction = Interaction.new(params)
  end
end
