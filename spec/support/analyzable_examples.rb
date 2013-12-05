module AnalyzableExamples
  def miliseconds_since_epoch(date)
    (date.beginning_of_day.to_i * 1000)
  end

  def eight_days_ago
    8.days.ago
  end

  def operator_name
    resource.user.operator_name
  end

  def country_code
    resource.user.country_code
  end

  shared_examples_for "filtering by operator" do
    context "passing :operator => '<operator>', :country_code => '<country_code>'" do
      it "should filter by the operator" do
        run_filter(:operator => :foo, :country_code => :kh).should be_empty
      end
    end
  end

  shared_examples_for "filtering by time" do
    context "passing :between => start_time..end_time" do
      it "should filter by the given timeline" do
        run_filter(:between => time_period).to_json.should == filtered_by_time_results.to_json
      end
    end
  end

  shared_examples_for "analyzable" do |skip_by_user|
    describe ".overview_of_created" do
      def two_months_and_one_day_ago
        2.months.ago - 1.day
      end

      def eight_days_ago_was_in_this_month
        (Time.current.month == eight_days_ago.month)
      end

      let(:resource) { create_resource }

      before do
        Timecop.freeze(Time.current)
        3.times { create_resource }
        2.times { create_resource.update_attribute(group_by_column, eight_days_ago) }
        resource.update_attribute(group_by_column, two_months_and_one_day_ago)
      end

      after do
        Timecop.return
      end

      it "should not results where the group_by_column is nil" do
        excluded_resource
        subject.class.overview_of_created.should_not include([0, 1])
      end

      context "passing no args" do
        it "should return an overview of all the created resources (in HighStocks format)" do
          subject.class.overview_of_created.should(
            include([miliseconds_since_epoch(two_months_and_one_day_ago), 1])
          )
        end
      end

      context "passing :timeframe_format => :report" do
        it "should return an overview of all the created resources (using the DOW format)" do
          subject.class.overview_of_created(
            :timeframe_format => :report
          ).should include([two_months_and_one_day_ago.day, 1])
        end
      end

      context "passing :least_recent => 2.months" do
        it "should return an overview of the resources created in the last 2 months" do
          subject.class.overview_of_created(
            :least_recent => 2.months
          ).should_not(
            include(
              [miliseconds_since_epoch(two_months_and_one_day_ago), 1]
            )
          )
        end
      end

      context "passing :between => 3.months.ago..2.month.ago" do
        it "should return an overview of the resources created in the timeline given" do
          subject.class.overview_of_created(
            :between => 3.months.ago..2.months.ago
          ).should == [[miliseconds_since_epoch(two_months_and_one_day_ago), 1]]
        end
      end

      context "passing :timeframe => :month" do
        it "should return an overview of all the created resources by month" do
          beginning_of_month = miliseconds_since_epoch(eight_days_ago.beginning_of_month)
          assertion = [beginning_of_month]
          eight_days_ago_was_in_this_month ? assertion << 5 : assertion << 2
          subject.class.overview_of_created(
            :timeframe => :month
          ).should(include(assertion))
        end
      end

      context "passing :operator => '<operator>', :country_code => '<country_code>'" do
        it "should filter by the given operator" do
          subject.class.overview_of_created(
            :operator => "foo", :country_code => country_code
          ).should be_empty

          subject.class.overview_of_created(
            :operator => operator_name, :country_code => "different"
          ).should be_empty

          subject.class.overview_of_created(
            :operator => operator_name, :country_code => country_code
          ).should_not be_empty
        end
      end

      unless skip_by_user
        context "passing :by_user => true" do
          before do
            user = create(:user)
            3.times { create_resource(:user => user).update_attribute(group_by_column, 7.days.ago) }
          end

          it "should return an overview of the resources created in the last 2 months by user" do
            subject.class.overview_of_created(:by_user => true).should == [
              [miliseconds_since_epoch(two_months_and_one_day_ago), 1],
              [miliseconds_since_epoch(eight_days_ago), 2],
              [miliseconds_since_epoch(7.days.ago), 1],
              [miliseconds_since_epoch(Time.current), 3]
            ]
          end
        end
      end
    end
  end
end
