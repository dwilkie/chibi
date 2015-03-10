require 'rails_helper'

describe Location do
  include LocationHelpers

  describe "Thailand" do

    let(:address_examples) do
      {
        "bangkok" => {
          :abbreviations => ["BKK"],
          :expected_city => "Bangkok",
          :expected_latitude => 13.7563309,
          :expected_longitude => 100.5017651
        },

        "chiang mai" => {
          :expected_city => "Chiang Mai",
          :expected_latitude => 18.787747,
          :expected_longitude => 98.99312839999999
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
