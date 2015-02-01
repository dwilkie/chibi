require 'rails_helper'

# see the individual specs for each location under spec/models/location
describe Location do
  include LocationHelpers

  let(:location) { build(:location) }

  describe "factory" do
    it "should be valid" do
      expect(location).to be_valid
    end
  end

  describe "callbacks" do
    context "before_save" do
      it "should normalize the country code" do
        location.country_code = "KH"
        location.save
        expect(location.reload.country_code).to eq("kh")
      end
    end

    context "after_create" do
      include ActiveJobHelpers

      it "should try to determine the location" do
        location.address = "foo"
        expect_locate { trigger_job { location.save } }
      end
    end
  end

  it "should not be valid without a country code" do
    location.country_code = nil
    expect(location).not_to be_valid
  end

  describe "#locate!(address)" do
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
      expect(build(:location).locate!("")).to be_nil

      # try to locate without a country code
      subject.country_code = ""
      expect(subject.locate!("new york")).to be_nil

      # do not try to reverse geocode unless the latitude or longitude changes
      new_york = create(:location, :new_york)

      VCR.use_cassette("no_results", :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]) do
        # this should not raise a vcr error
        new_york.locate!("some new address")
      end
    end
  end

  describe "#country_code" do
    it "should return a lowercase string of the country code" do
      subject.country_code = :AB
      expect(subject.country_code).to eq("ab")
    end

    it "should return nil if the country code is nil" do
      expect(subject.country_code).to be_nil
    end
  end
end
