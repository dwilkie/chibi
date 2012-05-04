shared_examples_for "analyzable" do
  let(:analyzable_resource) { create(subject.class.to_s.underscore) }
  let(:analyzable_resource_from_last_month) { create("#{subject.class.to_s.underscore}_from_last_month") }

  describe ".this_month" do
    before do
      analyzable_resource
      analyzable_resource_from_last_month
    end

    it "should return all the messages from this month" do
      subject.class.this_month.should == [analyzable_resource]
    end
  end
end
