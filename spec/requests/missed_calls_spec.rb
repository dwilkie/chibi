require 'spec_helper'

describe "Missed Calls" do
  include MissedCallHelpers

  describe "POST /missed_calls" do
    context "as a user" do
      context "when I call the test number" do
        context "and my call is missed" do

          it "should call me back" do
            expect_call(:to => "855973243313") do
              missed_call(:number => "0973243313")
            end
          end
        end
      end
    end
  end
end
