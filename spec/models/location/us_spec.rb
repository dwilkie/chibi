require 'spec_helper'

describe Location do
  include LocationHelpers

  ADDRESS_EXAMPLES = {
    "new york" => {
      :expected_city => "New York",
      :expected_latitude => 40.7143528,
      :expected_longitude => -74.00597309999999
    }
  }

  describe "US", :focus do
    describe "#locate!" do
      it "should determine the correct location and city from the address" do
        assert_locate!(:us, ADDRESS_EXAMPLES)
      end
    end

    describe ".country_code" do
      it "should return the correct country code from a mobile number" do
        assert_country_code(:us, "1415323456")
      end
    end
  end
end
