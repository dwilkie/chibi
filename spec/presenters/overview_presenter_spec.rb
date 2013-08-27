require 'spec_helper'

describe OverviewPresenter do
  include ActionView::TestCase::Behavior
  let(:sample_data) do
    {
      :new_users => [1122, 5],
      :messages_received => [6644, 4],
      :users_texting => [1122, 5],
      :return_users => [1122, 0],
      :inbound_cdrs => [1112, 7],
      :revenue => [6644, 0.06]
    }
  end

  let(:overview) do
    double(Overview, sample_data)
  end

  let(:presenter) { OverviewPresenter.new(overview, view) }

  def assert_highchart(identifier, result, assertions = {})

    highchart_options = JSON.parse(
      result.text.match(/options\s*=\s*(.+)\;/)[1]
    )

    highchart_options["title"]["text"].should == assertions[:title]

    chart_options = highchart_options["chart"]
    series_options = highchart_options["series"]

    chart_options["renderTo"].should == "#{identifier}_chart"

    chart_options["borderWidth"].should == 5
    chart_options["zoomType"].should == "y"

    sample_data.each_with_index do |(identifier, data_set), index|
      series_options[index]["name"].should == identifier.to_s.titleize
      series_options[index]["data"].should == data_set
    end
  end

  def capybara_string(input)
    Capybara.string(input)
  end

  def assert_overview_section(identifier, result, title = nil)
    title ||= identifier.to_s.titleize
    result = capybara_string(result)
    section = result.find("##{identifier}")
    section.should have_selector(".chart_title", :text => title)
    assert_highchart(identifier, section, :title => title)
    result.should have_selector(".separator")
  end

  def assert_overview_methods(options = {})
    sample_data.keys.each do |method|
      overview.should_receive(method).with(options)
    end
  end

  describe "#timeline" do
    context "passing no options" do
      it "should render a StockChart showing new users, messages and users texting by day" do
        assert_overview_methods
        assert_overview_section(:timeline_by_day, presenter.timeline)
      end
    end

    context "passing :timeframe => :month" do
      it "should render a StockChart showing new users, messages and users texting by month" do
        assert_overview_methods(:timeframe => :month)
        assert_overview_section(:timeline_by_month, presenter.timeline(:timeframe => :month))
      end
    end
  end
end
