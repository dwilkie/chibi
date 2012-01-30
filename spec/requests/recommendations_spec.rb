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

  let(:replies) do
    Reply.all
  end

  let(:reply_to_user) do
    replies[0]
  end

  let(:reply_to_friend) do
    replies[1]
  end

  let(:new_user) do
    User.last
  end

  let(:new_location) do
    Location.last
  end

  let(:my_number) { "8553243313" }

  def load_users
    USERS.each do |user|
      send(user)
    end
  end

  context "as a user" do
    context "given there are no matches for me" do
      context "when I text 'hello'" do
        before do
          VCR.use_cassette("no_results", :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]) do
            send_message(:from => my_number, :body => "hello")
          end
        end

        it "should reply saying there are no matches at this time" do
          replies.count.should == 1

          reply.body.should == spec_translate(
            :could_not_start_new_chat,
            :users_name => nil,
            :locale => :kh
          )

          reply.to.should == my_number
        end
      end
    end
  end

  context "as an existing user" do
    before do
      load_users
    end

    context "when I text" do
    end
  end

  context "as new user" do

    def assert_new_user
      new_user.mobile_number.should == my_number
      new_location.user.should == new_user
      new_location.country_code.should == "KH"
    end

    before do
      load_users
    end

    context "when I text" do

      context "'hello'" do
        before do
          Faker::Name.stub(:first_name).and_return("Wilfred")
          VCR.use_cassette("no_results", :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:address)]) do
            send_message(:from => my_number, :body => "hello")
          end
        end

        it "should start a chat between the new user and an existing user and notify both users" do
          assert_new_user

          reply_to_user.body.should == spec_translate(
            :new_chat_started,
            :users_name => nil,
            :friends_screen_name => "alex" + alex.id.to_s,
            :to_user => true,
            :locale => :kh
          )
          reply_to_user.to.should == my_number

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

      context "'knyom map 27 pp jong rok met srey'" do
        before do
          VCR.use_cassette("results", :erb => true) do
            send_message(:from => my_number, :body => "knyom map 27 pp jong rok met srey")
          end
        end

        it "should create a new user called 'map' and start a chat with a girl close to phnom penh" do
          assert_new_user

          new_user.name.should == "map"
          new_user.age.should == 27
          new_user.location.city.should == "Phnom Penh"
          new_user.looking_for.should == "f"
          new_user.gender.should be_nil
        end
      end
    end
  end
end
