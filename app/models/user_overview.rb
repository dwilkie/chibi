class UserOverview < AbstractFilter
  def paginated_users
    User.filter_by(params).page params[:page]
  end

  def total_users
    User.filter_by_count(params)
  end

  def total_available_users
    User.filter_params(available).count
  end

  def total_available_males
    User.filter_params(available(:gender => "m")).count
  end

  def total_available_females
    User.filter_params(available(:gender => "f")).count
  end

  private

  def available(filter_params = {})
    params.merge(:available => true).merge(filter_params)
  end
end
