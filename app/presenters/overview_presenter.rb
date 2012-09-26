class OverviewPresenter < BasePresenter
  presents :overview

  def new_users
    high_stock_chart_for("new_users", overview.new_users)
  end

  private

  def high_stock_chart_for(identifier, data, title = nil)
    title ||= identifier.titleize
    chart_div_id = "#{identifier}_chart"
    content_tag(:div, :class => "overview_section", :id => identifier) do
      content_tag(:h2, title) +
      content_tag(:div, :id => chart_div_id) do
        generate_chart(chart_div_id, data, title)
      end
    end
  end

  def generate_chart(identifier, data, title)
    chart = LazyHighCharts::HighChart.new do |f|
      f.options[:title][:text] = title
      f.options[:chart][:borderWidth] = 5
      f.series(:name => title, :data => data)
    end

    high_stock(identifier, chart)
  end
end
