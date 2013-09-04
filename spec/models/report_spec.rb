require 'spec_helper'

describe Report do
  describe "#generate!" do
    include MobilePhoneHelpers
    include TimecopHelpers
    include CdrHelpers

    subject { Report.new(:month => 1, :year => 2014) }

    def increment_daily_interactions(daily_report, key, options = {})
      options[:by] ||= 1

      interaction_report = daily_report[key] ||= {}
      interaction_report[options[:day]] ||= 0
      interaction_report[options[:day]] += options[:by]
    end

    def create_sample_interaction(options)
      report = options[:report] ||= {}
      Timecop.freeze(sometime_in(options)) do
        with_operators do |number_parts, assertions|
          full_number = number_parts.join

          create(:message, :from => full_number)
          create_cdr(
            :cdr_variables => {
              "variables" => {
                "sip_from_user" => full_number, "duration" => "60", "billsec" => "59"
              }
            }
          )

          next unless subject.month == options[:month] && options[:year] == options[:year]
          country_report = report[assertions["country_id"]] ||= {}
          operator_report = country_report[assertions["id"]] ||= {}
          daily_report = operator_report["daily"] ||= {}

          increment_daily_interactions(daily_report, "messages", options)
          if assertions["dial_string"]
            ivr_report = daily_report["ivr"] ||= {}
            increment_daily_interactions(ivr_report, "duration", options.merge(:by => 2))
            increment_daily_interactions(ivr_report, "bill_sec", options)
          end
        end
      end
    end

    let(:asserted_report) do
      report = {}
      create_sample_interaction(:day => 1, :month => 1, :year => 2014, :report => report)
      create_sample_interaction(:day => 31, :month => 1, :year => 2014, :report => report)
      create_sample_interaction(:day => 15, :month => 12, :year => 2013, :report => report)
      report
    end

    it "should generate a report", :focus do
      asserted_report
      subject.generate!.should == asserted_report
    end
  end
end
