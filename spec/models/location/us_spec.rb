require 'spec_helper'

describe Location do
  include LocationHelpers

  describe "US" do

    let(:address_examples) do
      {
        "new york" => {
          :expected_city => "New York",
          :expected_latitude => 40.7143528,
          :expected_longitude => -74.00597309999999
        }
      }
    end

    describe "#locate!" do
      it "should determine the correct location and city from the address" do
        assert_locate!(:us, address_examples)
      end
    end

    describe ".country_code" do
      it "should return the correct country code from a mobile number" do
        assert_country_code(:us, "1415323456")
      end
    end
  end
end
