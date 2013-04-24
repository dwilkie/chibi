require 'spec_helper'

describe Location do
  include LocationHelpers

  describe "US" do
    let(:new_york) { build(:location, :new_york) }

    let(:address_examples) do
      {
        "new york" => {
          :expected_city => new_york.city,
          :expected_latitude => new_york.latitude,
          :expected_longitude => new_york.longitude
        }
      }
    end

    describe "#locate!" do
      it "should determine the correct location and city from the address" do
        assert_locate!(:us, address_examples)
      end
    end
  end
end
