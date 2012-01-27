require 'spec_helper'

# see the individual specs for each location under spec/models/location
describe Location do
  include LocationHelpers

  let(:location) { build(:location) }

  it "should not be valid without a country code" do
    location.country_code = nil
    location.should_not be_valid
  end

  describe ".country_code" do
    it "should return nil if passed nil" do
      subject.class.country_code(nil)
    end
  end

  describe "#locate!" do
    it "should skip geolocation if address or country code is blank and reject it if the address is in the wrong country" do

      # locating a city in the wrong country
      assert_locate!(
        :kh,
        "new york" => {
          :expected_city => nil,
          :expected_latitude => nil,
          :expected_longitude => nil
        }
      )

      # try to locate without an address
      build(:location).locate!.should be_nil

      # try to locate without a country code
      subject.country_code = "TH"
      subject.locate!.should be_nil
    end
  end

  describe "#country_code" do
    it "should return an uppercase string of the country code" do
      subject.country_code = :ab
      subject.country_code.should == "AB"
    end
  end

  describe "#locale" do
    it "should return a lowercase symbol of the country code" do
      subject.country_code = "AB"
      subject.locale.should == :ab
    end
  end
end
