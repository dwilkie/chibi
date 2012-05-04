require 'spec_helper'

describe Overview do
  analyzable_resources = [:messages, :replies, :users]
  time_periods = [:this_month]

  analyzable_resources.each do |analyzable_resources|
    time_periods.each do |time_period|
      resource = analyzable_resources.to_s.singularize
      describe "#total_#{analyzable_resources}_#{time_period}" do
        before do
          create(resource)
          create("#{resource}_from_last_month")
        end

        it "should return the total #{analyzable_resources} created #{time_period.to_s.humanize.downcase}" do
          subject.send("total_#{analyzable_resources}_#{time_period}").should == 1
        end
      end
    end
  end

  time_periods.each do |time_period|
    describe "#total_revenue_#{time_period}" do
      before do
        create(:message)
      end

      it "should return the total revenue #{time_period.to_s.humanize.downcase}" do
        subject.send("total_revenue_#{time_period}").should == ENV['REVENUE_PER_SMS'].to_f
      end
    end
  end
end
