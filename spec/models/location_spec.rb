require 'spec_helper'

describe Location, :focus do

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
    }
  ]

  it "should not be valid without a country code" do
    location.country_code = nil
    location.should_not be_valid
  end

  describe ".country_code" do
    MOBILE_NUMBER_EXAMPLES.each do |example|
      context "'#{example[:sample_number]}'" do
        it "should return '#{example[:expected_country_code]}'" do
          subject.class.country_code(example[:sample_number]).should == example[:expected_country_code]
        end
      end
    end
  end

  MOBILE_NUMBER_EXAMPLES.each do |example|
    context "#mobile_number = '#{example[:sample_number]}'" do
      before do
        location.mobile_number = example[:sample_number]
      end

      context "before validation" do
        before do
          location.valid?
        end
  
        it "should set the country code to '#{example[:expected_country_code]}'" do
          location.country_code.should == example[:expected_country_code]
        end
      end
    end
  end

  context "#country_code = 'KH'" do
    context "and #address = nil" do
      it "should not try to determine the city from the latitude and longitude" do
        FakeWeb.last_request.should be_nil
      end
    end
  end

  ADDRESS_EXAMPLES.each do |example|
    context "#country_code = '#{example[:country_code]}'" do
      before do
        location.country_code = example[:country_code]
      end
      
      context "and #address = '#{example[:address]}'" do
        before do
          location.address = example[:address]
        end

        context "before validation" do
          before do
            VCR.use_cassette(example[:address] + " " + example[:country_code].downcase) do
              location.valid?
            end
          end

          if example[:expected_latitude]
            it "should set the latitude from the address" do
              location.latitude.should == example[:expected_latitude]
            end
          else
            it "should not set the latitude from the address" do
              location.latitude.should be_nil
            end
          end

          if example[:expected_longitude]
            it "should set the longitude from the address" do
              location.longitude.should == example[:expected_longitude]
            end
          else
            it "should not set the longitude from the address" do
              location.longitude.should be_nil
            end
          end

          if example[:expected_city]
            it "should set the city from the latitude and longitude" do
              location.city.should == example[:expected_city]
            end
          else
            it "should not set the city from the latitude and longitude" do
              location.city.should be_nil
            end
          end
        end
      end
    end
  end
end

