require 'spec_helper'

describe "Admin" do
  include MessagingHelpers

  let(:user) { create(:user) }
  let(:another_user) { create(:user) }

  let(:message) { create(:message, :user => user, :body => "Hello", :chat => chat) }
  let(:another_message) { create(:message, :user => another_user, :body => "Goodbye", :chat => another_chat) }

  let(:reply) { create(:delivered_reply, :user => user, :body => "Hello", :chat => chat) }
  let(:another_reply) { create(:reply, :user => another_user, :body => "Goodbye", :chat => another_chat) }

  let(:chat) { create(:active_chat_with_single_user, :user => user, :friend => another_user, :created_at => 10.minutes.ago) }
  let(:another_chat) { create(:chat, :user => another_user, :friend => user, :created_at => 10.minutes.ago) }

  let(:phone_call) { create(:phone_call, :user => user, :chat => chat) }
  let(:another_phone_call) { create(:phone_call, :user => another_user, :chat => another_chat) }

  let(:users) { [another_user, user] }
  let(:messages) { [message, another_message] }
  let(:replies) { [reply, another_reply] }
  let(:chats) { [another_chat, chat] }
  let(:phone_calls) { [phone_call, another_phone_call] }

  let(:chatable_resources) { [messages, replies, phone_calls] }

  def authorize
    page.driver.browser.basic_authorize(
      ENV["HTTP_BASIC_AUTH_ADMIN_USER"], ENV["HTTP_BASIC_AUTH_ADMIN_PASSWORD"]
    )
  end

  context "without the username and password" do
    it "should deny me access" do
      [overview_path, users_path, chats_path, phone_calls_path, messages_path, replies_path].each do |path|
        visit path
        page.body.should have_content "Access denied"
      end
    end
  end

  context "as an admin" do
    before do
      authorize
    end

    def assert_message_index(*resources)
      assert_index :message, *resources, :reverse => true
    end

    def assert_reply_index(*resources)
      assert_index :reply, *resources, :reverse => true
    end

    def assert_phone_call_index(*resources)
      assert_index :phone_call, *resources, :reverse => true
    end

    def assert_index(resource_name, *resources)
      options = resources.extract_options!
      resources_name = resource_name.to_s.pluralize
      resources = send(resources_name) if resources.empty?
      resources.reverse! if options[:reverse]

      page.find(
        "#total_#{resources_name}"
      ).text.gsub(/\s/, "").should == "#{resources_name.titleize.gsub(/\s/, "")}(#{resources.count})"

      resources.each_with_index do |resource, index|
        within("##{resource_name}_#{index + 1}") do
          send("assert_#{resource_name}_show", resource)
        end
      end
    end

    def assert_user_show(reference_user)
      page.should have_css "#id", :text => reference_user.id.to_s
      page.should have_css "#name", :text => reference_user.name
      page.should have_css "#screen_name", :text => reference_user.screen_name
      page.should have_css "#date_of_birth", :text => reference_user.date_of_birth
      page.should have_css "#gender", :text => reference_user.gender
      page.should have_css "#city", :text => reference_user.city
      page.should have_css "#looking_for", :text => reference_user.looking_for
      page.should have_css "#online", :text => reference_user.online.to_s
      page.should have_css "#locale", :text => reference_user.locale
      within "#mobile_number" do
        page.should have_link reference_user.mobile_number, :href => user_path(reference_user)
      end

      assert_chatable_resources_counts(reference_user)
    end

    def assert_message_show(reference_message)
      page.should have_content reference_message.body
      page.should have_content reference_message.from
    end

    def assert_reply_show(reference_reply)
      page.should have_content reference_reply.body
      page.should have_content reference_reply.to
      if reference_reply.delivered?
        page.should have_content time_ago_in_words
      else
        page.should have_content "pending"
      end
    end

    def time_ago_in_words(created_at = nil)
      minutes_ago = ((Time.now - created_at.to_i.minutes.ago) / 60).round
      minutes_ago.zero? ? "less than a minute ago" : "#{minutes_ago} minutes ago"
    end

    def assert_phone_call_show(reference_phone_call)
      page.should have_content time_ago_in_words
      page.should have_link(
        reference_phone_call.from,
        :href => user_path(reference_phone_call.user_id)
      )
      page.should have_content reference_phone_call.state.humanize
    end

    def assert_chat_show(reference_chat)
      page.should have_content time_ago_in_words(10)
      page.should have_content reference_chat.active?

      assert_chatable_resources_counts(reference_chat)

      USER_TYPES_IN_CHAT.each do |user_type|
        within("##{user_type}") do
          reference_user = reference_chat.send(user_type)
          if screen_id = reference_user.try(:screen_id)
            page.should have_link screen_id, :href => user_path(reference_user)
          else
            page.should have_content screen_id
          end
        end
      end
    end

    def assert_chatable_resources_counts(resource)
      CHATABLE_RESOURCES.each do |chatable_resources|
        within("##{chatable_resources}") do
          chatable_resources_count = resource.send(chatable_resources).count
          chatable_resources_link = chatable_resources_count.to_s

          if chatable_resources_count.zero?
            page.should have_no_link(chatable_resources_link)
            page.should have_content(chatable_resources_link)
          else
            page.should have_link(
              chatable_resources_link,
              :href => send("#{resource.class.to_s.underscore}_#{chatable_resources}_path", resource)
            )
          end
        end
      end
    end

    def assert_show_user(reference_user)
      page.current_path.should == user_path(reference_user)
      assert_user_show(reference_user)
    end

    def assert_navigate_to_chatable_resource(resource_name)
      resources_name = resource_name.to_s.pluralize
      CHATABLE_RESOURCES.each do |chatable_resources|
        visit send("#{resources_name}_path")

        within("##{resource_name}_1 ##{chatable_resources}") do
          click_link(send(resource_name).send(chatable_resources).count.to_s)
        end

        chatable_resource = chatable_resources.to_s.singularize
        send("assert_#{chatable_resource}_index", send(chatable_resource))
      end
    end

    context "when I visit '/overview'" do
      let(:message_from_last_month) { create(:message_from_last_month, :user => user) }
      let(:reply_from_last_month) { create(:reply_from_last_month, :user => user) }
      let(:user_from_last_month) { create(:user_from_last_month) }

      before do
        messages
        message_from_last_month
        replies
        reply_from_last_month
        users
        user_from_last_month
        visit overview_path
      end

      it "should show me an overview of Chibi" do
        within "#this_month" do
          within "#total_messages" do
            page.should have_link "#{messages.count} messages", :href => messages_path
          end

          within "#total_replies" do
            page.should have_link "#{replies.count} replies", :href => replies_path
          end

          within "#total_users" do
            page.should have_link "#{users.count} new users", :href => users_path
          end

          within "#total_revenue" do
            page.should have_content "$0.03"
          end
        end
      end
    end

    context "given some chats" do
      before do
        chats
        chatable_resources
      end

      context "when I visit '/chats'" do
        before do
          visit chats_path
        end

        it "should show me a list of chats" do
          assert_index :chat, :reverse => true
        end

        context "when I click on screen id for one of the chat participants" do
          it "should show the user" do
            USER_TYPES_IN_CHAT.each do |user_type|
              visit chats_path

              user_resource = chat.send(user_type)

              within("#chat_1 ##{user_type}") do
                click_link(user_resource.screen_id)
              end

              assert_show_user(user_resource)
            end
          end
        end

        context "when I click on the number of chatable resources for one of the chats" do
          it "should show me a list of the chatable resources" do
            assert_navigate_to_chatable_resource(:chat)
          end
        end
      end
    end

    context "given some messages" do
      before do
        messages
      end

      context "when I visit '/messages'" do
        before do
          visit messages_path
        end

        it "should show me a list of messages" do
          assert_message_index
        end
      end
    end

    context "given some replies" do
      before do
        replies
      end

      context "when I visit '/replies'" do
        before do
          visit replies_path
        end

        it "should show me a list of replies" do
          assert_reply_index
        end
      end
    end

    context "given some phone calls" do
      before do
        phone_calls
      end

      context "when I visit '/phone_calls'" do
        before do
          visit phone_calls_path
        end

        it "should show me a list of phone calls" do
          assert_phone_call_index
        end
      end
    end

    context "given some users" do
      before do
        users
        chatable_resources
      end

      context "when I visit '/users'" do
        before do
          visit users_path
        end

        it "should show me a list of users" do
          assert_index :user, :reverse => true
        end

        context "when I click on 'X' for one of the users" do
          before do
            within("#user_1") do
              click_link("X")
            end
          end

          it "should delete the user" do
            within("#user_1") do
              page.should have_content another_user.id
            end

            page.should have_no_css "#user_2"
          end
        end

        context "when I click on the number of chatable resources for one of the users" do
          it "should show me a list of the chatable resources" do
            assert_navigate_to_chatable_resource(:user)
          end
        end

        context "when I click on the mobile number for one of the users" do
          before do
            within("#user_1") do
              click_link(user.mobile_number)
            end
          end

          it "should show me the user" do
            assert_show_user(user)
          end
        end
      end
    end
  end
end
