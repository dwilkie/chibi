class Interaction < AbstractFilter
  def total_messages
    resources(:message).count
  end

  def total_replies
    resources(:reply).count
  end

  def total_phone_calls
    resources(:phone_call).count
  end

  def paginated_interactions
    @paginated_interactions ||= (paginated(:message) | paginated(:reply) | paginated(:phone_call)).sort_by(&:updated_at).reverse
  end

  private

  def resources(name)
    name.to_s.classify.constantize.filter_by(params)
  end

  def paginated(name)
    resources(name).page params[:page]
  end
end
