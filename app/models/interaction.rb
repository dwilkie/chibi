class Interaction
  def initialize(params = {})
    @params = params
  end

  def paginated_interactions
    @paginated_interactions ||= (paginated(:message) | paginated(:phone_call)).sort_by(&:created_at)
  end

  private

  def params
    @params
  end

  def resources(name)
    name.to_s.classify.constantize.filter_by(params)
  end

  def paginated(name)
    resources(name).page params[:page]
  end
end
