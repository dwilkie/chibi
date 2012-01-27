require 'spec_helper'

describe "Initiating a chat" do
  include MessagingHelpers
  include TranslationHelpers

  USERS = [:dave, :nok, :mara, :alex]

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

  def load_users
    USERS.each do |user|
      send(user)
    end
  end

  before do
    load_users
  end

  context "as new user" do
    context "when I text" do
      let(:my_number) { "8553243313" }

      context "'hello'" do
        before do
          Faker::Name.stub(:first_name).and_return("Wilfred")
          VCR.use_cassette("no_results", :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]) do
            send_message(:from => my_number, :body => "hello")
          end
        end

        it "should start a chat between the new user and an existing user and notify both users" do
          new_user.mobile_number.should == my_number
          new_location.user.should == new_user
          new_location.country_code.should == "KH"

          replies = Reply.all

          reply_to_user = replies[0]

          reply_to_user.body.should == spec_translate(
            :new_chat_started,
            :users_name => nil,
            :friends_screen_name => "alex" + alex.id.to_s,
            :to_user => true,
            :locale => :kh
          )
          reply_to_user.to.should == my_number

          reply_to_friend = replies[1]

          reply_to_friend.body.should == spec_translate(
            :new_chat_started,
            :users_name => "Alex",
            :friends_screen_name => "wilfred" + new_user.id.to_s,
            :to_user => false,
            :locale => :kh
          )

          reply_to_friend.to.should == alex.mobile_number
        end
      end
    end
  end
end
