require 'spec_helper'

describe "Home Page" do
  before do
    visit root_path
  end

  it "should show me the home page" do
    current_path.should == root_path
    page.should have_content "Chibi"
  end
end
