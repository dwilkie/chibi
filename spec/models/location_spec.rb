require 'spec_helper'

describe Location do

  let(:location) { build(:location) }

  MOBILE_NUMBER_EXAMPLES = [
    {
      :sample_number => "85512234456",
      :expected_country_code => "KH"
    },
    {
      :sample_number => "84188324443",
      :expected_country_code => "VN"
    },
    {
      :sample_number => "61412345678",
      :expected_country_code => "AU"
    },
    {
      :sample_number => "1415323456",
      :expected_country_code => "US"
    }
  ]

  ADDRESS_EXAMPLES = [
    {
      :country_code => "KH",
      :address => "phnom penh",
      :expected_city => "Phnom Penh",
      :expected_latitude => 11.558831,
      :expected_longitude => 104.917445
    },
    {
      :country_code => "KH",
      :address => "siem reab",
      :expected_city => "Siem Reap",
      :expected_latitude => 13.3622222,
      :expected_longitude => 103.8597222
    },
    {
      :country_code => "KH",
      :address => "battambong",
      :expected_city => "Battambang",
      :expected_latitude => 13.1,
      :expected_longitude => 103.2
    },
    {
      :country_code => "KH",
      :address => "new york",
      :expected_city => nil,
      :expected_latitude => nil,
      :expected_longitude => nil
    },
    {
      :country_code => "US",
      :address => "new york",
      :expected_city => "New York",
      :expected_latitude => 40.7143528,
      :expected_longitude => -74.00597309999999
    },
    {
      :country_code => "TH",
      :address => "chang mai",
      :expected_city => "Samoeng",
      :expected_latitude => 18.7964642,
      :expected_longitude => 98.6600586
    }
  ]

  it "should not be valid without a country code" do
    location.country_code = nil
    location.should_not be_valid
  end

  describe ".country_code" do
    it "should return the correct country code from a mobile number" do
      MOBILE_NUMBER_EXAMPLES.each do |example|
        subject.class.country_code(example[:sample_number]).should == example[:expected_country_code]
      end
    end
  end

  describe "#locate!" do
    it "should determine the correct location and city from the address and country code" do
      ADDRESS_EXAMPLES.each do |example|
        subject = build(:location)
        subject.country_code = example[:country_code]

        subject.address = example[:address]
        VCR.use_cassette(example[:address] + " " + example[:country_code].downcase) do
          subject.locate!
        end

        [:latitude, :longitude, :city].each do |attribute|
          expected = example["expected_#{attribute}".to_sym]
          actual = subject.send(attribute)
          expected ? actual.should == expected : actual.should(be_nil)
        end
      end

      # try to locate without an address
      build(:location).locate!.should be_nil

      # try to locate without a country code
      subject.country_code = "TH"
      subject.locate!.should be_nil
    end
  end
end
