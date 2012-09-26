require 'spec_helper'

describe OverviewPresenter do
  include ActionView::TestCase::Behavior
  let(:sample_data) { [1234, 5] }
  let(:overview) { mock(Overview, :new_users => sample_data) }
  let(:presenter) { OverviewPresenter.new(overview, view) }

  def assert_highchart(identifier, result, assertions = {})
    chart_identifier = "#{identifier}_chart"

    highchart_options = JSON.parse(
      result.find(
        "##{chart_identifier} script"
      ).text.match(/options\s*=\s*(.+)\;/)[1]
    )

    highchart_options["title"]["text"].should == assertions[:title]

    chart_options = highchart_options["chart"]
    series_options = highchart_options["series"].first

    chart_options["renderTo"].should == chart_identifier
    chart_options["borderWidth"].should == 5

    series_options["name"].should == assertions[:title]
    series_options["data"].should == sample_data
  end

  def capybara_string(input)
    Capybara.string(input)
  end

  describe "#new_users", :focus do
    it "render a StockChart for new users" do
      result = capybara_string(presenter.new_users)
      title = "New Users"
      result.find("#new_users")
      result.should have_selector("h2", :text => title)
      assert_highchart(:new_users, result, :title => title)
    end
  end
end
