require 'spec_helper'

describe Location do
  include LocationHelpers

  describe "Thailand" do

    let(:address_examples) do
      {
        "chiang mai" => {
          :expected_city => "Samoeng",
          :expected_latitude => 18.7964642,
          :expected_longitude => 98.6600586
        }
      }
    end

    describe "#locate!" do
      it "should determine the correct location and city from the address" do
        assert_locate!(:th, address_examples)
      end
    end
  end
end
