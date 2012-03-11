# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120307094401) do

  create_table "chats", :force => true do |t|
    t.integer  "user_id"
    t.integer  "friend_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "chats", ["friend_id"], :name => "index_chats_on_friend_id"
  add_index "chats", ["updated_at"], :name => "index_chats_on_updated_at"
  add_index "chats", ["user_id"], :name => "index_chats_on_user_id"

  create_table "interests", :force => true do |t|
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "locations", :force => true do |t|
    t.string   "city"
    t.string   "country_code"
    t.float    "latitude"
    t.float    "longitude"
    t.integer  "user_id"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
  end

  add_index "locations", ["country_code"], :name => "index_locations_on_country_code"
  add_index "locations", ["user_id"], :name => "index_locations_on_user_id"

  create_table "messages", :force => true do |t|
    t.string   "from"
    t.text     "body"
    t.integer  "user_id"
    t.integer  "chat_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "messages", ["chat_id"], :name => "index_messages_on_chat_id"
  add_index "messages", ["user_id"], :name => "index_messages_on_user_id"

  create_table "mo_messages", :force => true do |t|
    t.string   "from"
    t.string   "body"
    t.string   "guid"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "mt_messages", :force => true do |t|
    t.string   "body"
    t.integer  "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "phone_calls", :force => true do |t|
    t.integer  "sid"
    t.string   "from"
    t.string   "state"
    t.integer  "user_id"
    t.integer  "chat_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "phone_calls", ["chat_id"], :name => "index_phone_calls_on_chat_id"
  add_index "phone_calls", ["sid"], :name => "index_phone_calls_on_sid", :unique => true
  add_index "phone_calls", ["state"], :name => "index_phone_calls_on_state"
  add_index "phone_calls", ["user_id"], :name => "index_phone_calls_on_user_id"

  create_table "replies", :force => true do |t|
    t.string   "to"
    t.string   "body"
    t.integer  "user_id"
    t.integer  "chat_id"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "replies", ["chat_id"], :name => "index_replies_on_chat_id"
  add_index "replies", ["user_id"], :name => "index_replies_on_user_id"

  create_table "user_interests", :force => true do |t|
    t.integer  "user_id"
    t.integer  "interest_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "mobile_number"
    t.string   "name"
    t.string   "screen_name"
    t.date     "date_of_birth"
    t.string   "gender",         :limit => 1
    t.string   "looking_for",    :limit => 1
    t.boolean  "online",                      :default => true, :null => false
    t.integer  "active_chat_id"
    t.datetime "created_at",                                    :null => false
    t.datetime "updated_at",                                    :null => false
  end

  add_index "users", ["active_chat_id"], :name => "index_users_on_active_chat_id"
  add_index "users", ["date_of_birth"], :name => "index_users_on_date_of_birth"
  add_index "users", ["gender"], :name => "index_users_on_gender"
  add_index "users", ["looking_for"], :name => "index_users_on_looking_for"
  add_index "users", ["mobile_number"], :name => "index_users_on_mobile_number", :unique => true
  add_index "users", ["online"], :name => "index_users_on_online"

end
