class OverviewPresenter < BasePresenter
  presents :overview

  def timeline(options = {})
    overview.timeframe = options[:timeframe] || :day
    high_stock_chart_for(
      "timeline_by_#{overview.timeframe}",
      :new_users => overview.new_users,
      :return_users => overview.return_users,
      :users_texting => overview.users_texting,
      :messages_received => overview.messages_received,
      :phone_calls => overview.phone_calls,
      :inbound_cdrs => overview.inbound_cdrs,
      :ivr_bill_minutes => overview.ivr_bill_minutes
    )
  end

  def menu
    content_tag(:div, :class => :menu) do
      content_tag(:ul) do
        content_tag(:li) do
          report_link
        end
      end
    end
  end

  private

  def report_link
    time_last_month = (Time.current - 1.month)
    last_month = time_last_month.month
    last_month_year = time_last_month.year
    link_to(
      "create report for #{time_last_month.strftime('%B %Y')}",
      report_path(:report => {:year => last_month_year, :month => last_month}),
      :method => :post
    )
  end

  def high_stock_chart_for(identifier, data_sets)
    title = identifier.titleize
    chart_div_id = "#{identifier}_chart"
    result = content_tag(:div, :class => "overview_section", :id => identifier) do
      content_tag(:h2, title, :class => "chart_title") +
      generate_chart(chart_div_id, title, data_sets)
    end
    result + tag(:hr, :class => "separator")
  end

  def generate_chart(identifier, title, data_sets)
    chart = LazyHighCharts::HighChart.new do |f|
      f.options[:title][:text] = title
      f.options[:chart][:borderWidth] = 5
      f.options[:chart][:zoomType] = "y"
      data_sets.each do |series_id, data|
        f.series(:name => series_id.to_s.titleize, :data => data)
      end
    end

    high_stock(identifier, chart)
  end
end
