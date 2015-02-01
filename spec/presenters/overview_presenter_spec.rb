require 'rails_helper'

describe OverviewPresenter do
  include ActionView::TestCase::Behavior
  let(:sample_data) do
    {
      :new_users => [1122, 5],
      :return_users => [1122, 0],
      :users_texting => [1122, 5],
      :messages_received => [6644, 4],
      :phone_calls => [1112, 6],
      :inbound_cdrs => [1112, 7],
      :ivr_bill_minutes => [1112, 440]
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

    expect(highchart_options["title"]["text"]).to eq(assertions[:title])

    chart_options = highchart_options["chart"]
    series_options = highchart_options["series"]

    expect(chart_options["renderTo"]).to eq("#{identifier}_chart")

    expect(chart_options["borderWidth"]).to eq(5)
    expect(chart_options["zoomType"]).to eq("y")

    sample_data.each_with_index do |(identifier, data_set), index|
      expect(series_options[index]["name"]).to eq(identifier.to_s.titleize)
      expect(series_options[index]["data"]).to eq(data_set)
    end
  end

  def capybara_string(input)
    Capybara.string(input)
  end

  def assert_overview_section(identifier, result, title = nil)
    title ||= identifier.to_s.titleize
    result = capybara_string(result)
    section = result.find("##{identifier}")
    expect(section).to have_selector(".chart_title", :text => title)
    assert_highchart(identifier, section, :title => title)
    expect(result).to have_link("All", :href => overview_path(:all => true))
    expect(result).to have_link("6 Months", :href => overview_path)
    expect(result).to have_selector(".separator")
  end

  def assert_overview_methods
    sample_data.keys.each do |method|
      expect(overview).to receive(method)
    end
  end

  describe "#timeline" do
    before do
      allow(overview).to receive(:timeframe=)
    end

    context "passing no options" do
      before do
        allow(overview).to receive(:timeframe).and_return(:day)
      end

      it "should render a StockChart showing an overview by day" do
        expect(overview).to receive(:timeframe=).with(:day)
        assert_overview_methods
        assert_overview_section(:timeline_by_day, presenter.timeline)
      end
    end

    context "passing :timeframe => :month" do
      before do
        allow(overview).to receive(:timeframe).and_return(:month)
      end

      it "should render a StockChart showing an overview by month" do
        expect(overview).to receive(:timeframe=).with(:month)
        assert_overview_methods
        assert_overview_section(:timeline_by_month, presenter.timeline(:timeframe => :month))
      end
    end
  end

  describe "#menu" do
    include TimecopHelpers

    context "given it's January 2014" do
      before do
        Timecop.freeze(sometime_in(:year => 2014, :month => 1))
      end

      after do
        Timecop.return
      end

      it "should return a link to create a report for December 2013" do
        result = capybara_string(presenter.menu)
        expect(result).to have_link(
          "create report for December 2013", :href => report_path(
            :report => {:month => 12, :year => 2013}
          )
        )
      end
    end

    context "given it's April 2014" do
      before do
        Timecop.freeze(sometime_in(:year => 2014, :month => 4))
      end

      after do
        Timecop.return
      end

      it "should return a link to create a report for March 2014" do
        result = capybara_string(presenter.menu)
        expect(result).to have_link(
          "create report for March 2014", :href => report_path(
            :report => {:year => 2014, :month => 3}
          )
        )
      end
    end
  end
end
