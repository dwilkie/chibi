class Overview
  analyzable_resources = [:messages, :replies, :users]
  time_periods = [:this_month]

  time_periods.each do |time_period|
    define_method("total_revenue_#{time_period}") do
      ENV['REVENUE_PER_SMS'].to_f * send("total_messages_#{time_period}")
    end
  end

  analyzable_resources.each do |analyzable_resource|
    time_periods.each do |time_period|

      private_helper_method = "#{analyzable_resource}_#{time_period}"

      define_method("total_#{private_helper_method}") do
        send(private_helper_method).count
      end

      define_method(private_helper_method) do
        send(analyzable_resource).send(time_period)
      end

      private private_helper_method
    end

    define_method(analyzable_resource) do
      analyzable_resource.to_s.classify.constantize.scoped
    end

    private analyzable_resource
  end
end
