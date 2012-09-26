class OverviewPresenter < BasePresenter
  presents :overview

  def timeline(options = {})
    timeframe = options[:timeframe] || :day
    high_stock_chart_for(
      "timeline_by_#{timeframe}",
      :new_users => overview.new_users(options),
      :messages_received => overview.messages_received(options),
      :users_texting => overview.users_texting(options)
    )
  end

  private

  def high_stock_chart_for(identifier, data_sets)
    title = identifier.titleize
    chart_div_id = "#{identifier}_chart"
    result = content_tag(:div, :class => "overview_section", :id => identifier) do
      content_tag(:h2, title, :class => "chart_title") +
      content_tag(:div, :id => chart_div_id) do
        generate_chart(chart_div_id, title, data_sets)
      end
    end
    result + tag(:hr, :class => "separator")
  end

  def generate_chart(identifier, title, data_sets)
    chart = LazyHighCharts::HighChart.new do |f|
      f.options[:title][:text] = title
      f.options[:chart][:borderWidth] = 5
      data_sets.each do |series_id, data|
        f.series(:name => series_id.to_s.titleize, :data => data)
      end
    end

    high_stock(identifier, chart)
  end
end