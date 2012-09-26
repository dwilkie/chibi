shared_examples_for "analyzable" do
  let(:resource_name) { subject.class.to_s.underscore }

  describe ".overview_of_created" do
    def two_months_and_one_day_ago
      2.months.ago - 1.day
    end

    def miliseconds_since_epoch(date)
      (date.to_date.to_datetime.to_i * 1000)
    end

    before do
      Timecop.freeze(Time.now)
      create_list(resource_name, 3)
      create_list(resource_name, 2, :created_at => 8.day.ago)
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

    context "passing 2.months" do
      it "should return an overview of the resources created in the last 2 months (in HighStocks format)" do
        subject.class.overview_of_created(2.months).should == [
          [miliseconds_since_epoch(8.days.ago), 2],
          [miliseconds_since_epoch(Date.today), 3]
        ]
      end
    end
  end
end
