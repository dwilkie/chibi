require 'spec_helper'

describe "Initiating a chat" do
  include MessagingHelpers
  include TranslationHelpers

  USERS = [:dave, :nok, :mara]

  USERS.each do |user|
    let(user) { create(user) }
  end

  let(:reply) do
    Reply.last
  end

  let(:new_user) do
    User.last
  end

  let(:new_location) do
    Location.last
  end

  let(:new_chat) do
    Chat.last
  end

  before do
    USERS.each do |user|
      user
    end
  end

  context "as new user", :focus do
    context "when I text" do
      let(:my_number) { "8553243313" }

      context "'hello'" do
        before do
          VCR.use_cassette("no_results", :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]) do
            send_message(:from => my_number, :body => "hello")
          end
        end

        it "should start a chat between the new user and an existing user" do
          new_user.mobile_number.should == my_number
          new_location.user.should == new_user
          new_location.country_code.should == "KH"
          new_chat.user.should == new_user
          reply.body.should == spec_translate(
            :new_match,
            :name => nil,
            :match => sok
          )
          reply.to.should == my_number
        end
      end
    end
  end

  context "as an existing user" do
    context "and there are other users in the system", :search => true do

      before(:all) do
        reload_index_and_commit(users)
      end

      context "when he searches" do
        before(:all) do
          search(sok)
        end

        it "should find him a match" do
          reply.body.should == spec_translate(
            :new_match,
            :name => sok.name,
            :match => boy_looking_for_a_friend
          )
        end
      end
    end

    shared_examples_for "recommend sok some users to chat with" do
      before do
        send_message(:from => sok.mobile_number,:body => message_text)
      end

      context "the last message" do
        it "should have a reply" do
          last_message.reply.should be_present
        end

        context "reply" do
          it "should be sent to Sok" do
            reply.subscription.user.should == sok
          end

          it "should contain some recommendations" do
            reply.body.should == spec_translate(
              :suggestions,
              :looking_for => sok.looking_for,
              :usernames => []
            )
          end
        end
      end
    end
  end
end
