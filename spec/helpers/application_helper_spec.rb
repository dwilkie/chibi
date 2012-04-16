require 'spec_helper'

describe ApplicationHelper do

  describe "#heading_with_count" do

    before do
      helper.extend Haml
      helper.extend Haml::Helpers
      helper.send :init_haml_helpers
    end

    it "should return a h2 heading with the resource and the count" do
      helper.heading_with_count(:phone_calls, 5).should have_css(
        "h2#total_phone_calls", :text => "Phone Calls (5)"
      )
    end
  end
end
