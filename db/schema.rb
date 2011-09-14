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

ActiveRecord::Schema.define(:version => 20110911070204) do

  create_table "interests", :force => true do |t|
    t.string   "description"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

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

  create_table "user_interests", :force => true do |t|
    t.integer  "user_id"
    t.integer  "interest_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", :force => true do |t|
    t.string   "mobile_number"
    t.string   "name"
    t.string   "username"
    t.date     "dob"
    t.string   "sex",           :limit => 1
    t.string   "location"
    t.string   "looking_for",   :limit => 1
    t.string   "state",                      :default => "newbie"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["dob"], :name => "index_users_on_dob"
  add_index "users", ["location"], :name => "index_users_on_location"
  add_index "users", ["looking_for"], :name => "index_users_on_looking_for"
  add_index "users", ["mobile_number"], :name => "index_users_on_mobile_number", :unique => true
  add_index "users", ["sex"], :name => "index_users_on_sex"
  add_index "users", ["username"], :name => "index_users_on_username", :unique => true

end
