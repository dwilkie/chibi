module LocationHelpers
  def assert_locate!(country_code, examples)
    examples.each do |address, expectation|

      sub_examples = expectation[:abbreviations] || []
      sub_examples << sub_examples.map { |example| example.upcase }
      sub_examples << address
      sub_examples.flatten!

      sub_examples.each do |sub_example|
        subject = build(:location)
        subject.country_code = country_code
        subject.address = sub_example
        result = nil

        VCR.use_cassette("#{country_code}/#{address}") do
          result = subject.locate!
        end

        [:latitude, :longitude, :city].each do |attribute|
          expected = expectation["expected_#{attribute}".to_sym]
          actual = subject.send(attribute)
          if expected
            actual.should == expected
            result.should == sub_example.downcase
          else
            actual.should be_nil
            result.should be_nil
          end
        end
      end
    end
  end
end
