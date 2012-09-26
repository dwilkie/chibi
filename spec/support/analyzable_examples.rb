shared_examples_for "analyzable" do |skip_by_user|
  let(:resource_name) { subject.class.to_s.underscore }

  describe ".overview_of_created" do
    def two_months_and_one_day_ago
      2.months.ago - 1.day
    end

    def eight_days_ago
      8.days.ago
    end

    def miliseconds_since_epoch(date)
      (date.to_date.to_datetime.to_i * 1000)
    end

    def eight_days_ago_was_in_this_month
      (Time.now.month == eight_days_ago.month)
    end

    before do
      Timecop.freeze(Time.now)
      create_list(resource_name, 3)
      create_list(resource_name, 2, :created_at => eight_days_ago)
      create(resource_name, :created_at => two_months_and_one_day_ago)
    end

    after do
      Timecop.return
    end

    context "passing no args" do
      it "should return an overview of all the created resources (in HighStocks format)" do
        subject.class.overview_of_created.should(
          include([miliseconds_since_epoch(two_months_and_one_day_ago), 1])
        )
      end
    end

    context "passing :least_recent => 2.months" do
      it "should return an overview of the resources created in the last 2 months (in HighStocks format)" do
        subject.class.overview_of_created(:least_recent => 2.months).should_not include(
          [miliseconds_since_epoch(two_months_and_one_day_ago), 1]
        )
      end
    end

    context "passing :timeframe => :month" do
      it "should return an overview of all the created resources by month" do
        beginning_of_month = miliseconds_since_epoch(eight_days_ago.beginning_of_month)
        assertion = [beginning_of_month]
        eight_days_ago_was_in_this_month ? assertion << 5 : assertion << 2
        subject.class.overview_of_created(:timeframe => :month).should include(assertion)
      end
    end

    unless skip_by_user
      context "passing :by_user => true" do
        before do
          user = create(:user)
          create_list(resource_name, 3, :user => user, :created_at => 7.days.ago)
        end

        it "should return an overview of the resources created in the last 2 months by user" do
          subject.class.overview_of_created(:by_user => true).should == [
            [miliseconds_since_epoch(two_months_and_one_day_ago), 1],
            [miliseconds_since_epoch(eight_days_ago), 2],
            [miliseconds_since_epoch(7.days.ago), 1],
            [miliseconds_since_epoch(Date.today), 3]
          ]
        end
      end
    end
  end
end
