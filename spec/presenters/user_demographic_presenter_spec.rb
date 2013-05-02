require 'spec_helper'

describe UserDemographicPresenter do
  include ActionView::TestCase::Behavior

  let(:presenter) { UserDemographicPresenter.new(nil, view) }

  def capybara_string(input)
    Capybara.string(input)
  end

  def page_section(id)
    @page_section ||= capybara_string(presenter.send(id)).find("##{id}")
  end

  def assert_title(result, title)
    result.should have_selector("h2", :text => title)
  end

  describe "#by_gender" do
    it "should show a summary of by gender statistics" do
      section = page_section(:by_gender)
      assert_title(section, "By Gender")
    end
  end
end
