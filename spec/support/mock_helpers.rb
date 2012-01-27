module MockHelpers
  def stub_match(options = {})
    unless options[:match] == false
      options[:match] ||= create(:user)
      User.stub(:matches).and_return([options[:match]])
    end
  end
end
