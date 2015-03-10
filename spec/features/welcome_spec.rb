require 'rails_helper'

describe "Home Page" do
  before do
    visit root_path
  end

  it "should show me the home page" do
    expect(current_path).to eq(root_path)
    expect(page).to have_content "Chibi"
  end
end
