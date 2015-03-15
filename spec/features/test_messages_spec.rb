require 'rails_helper'

describe "Test Messages" do
  include AdminHelpers

  context "without the username and password" do
    it "should deny me access" do
      visit new_test_message_path
      page.body.should have_content "Access denied"
    end
  end

  context "as an admin" do
    before do
      authorize
    end

    describe "successfully create a test message" do
      include MessagingHelpers

      let(:new_message) { Message.first }

      before do
        visit new_test_message_path
        fill_in "message_from", :with => "+6612345678"
        fill_in "message_body", :with => "Hello World"
        expect_locate { expect_message { click_button "Create Message" } }
      end

      it "should create a message and process it" do
        new_message.should be_processed
      end
    end

    describe "unsuccessfully create a test message" do
      let(:new_message) { Message.first }

      before do
        visit new_test_message_path
        click_button "Create Message"
      end

      it "should not create a message" do
        new_message.should_not be_present
        page.should have_content "can't be blank"
      end
    end
  end
end
