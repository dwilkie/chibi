# encoding: utf-8

require 'rails_helper'

describe Location do
  include LocationHelpers

  describe "Cambodia" do

    let(:address_examples) do
      {
        "phnom penh" => {
          :abbreviations => ["pp", "p.p"],
          :expected_city => "Phnom Penh",
          :expected_latitude => 11.5448729,
          :expected_longitude => 104.8921668
        },

        "siem reab" => {
          :abbreviations => ["sr", "s.r", "siem reap"],
          :expected_city => "Banteay Srei",
          :expected_latitude => 13.6915377,
          :expected_longitude => 104.1001326
        },

        "kracheh" => {
          :abbreviations => ["kr.ch", "kr", "k.r", "kratie"],
          :expected_city => "Kracheh",
          :expected_latitude => 12.8606299,
          :expected_longitude => 105.9699878
        },

        "mondol kiri" => {
          :abbreviations => ["m.ri", "mk", "m.k", "mondolkiri", "mondulkiri"],
          :expected_city => "Dei-Ey",
          :expected_latitude => 12.78794270,
          :expected_longitude => 107.10119310
        },

        "preah vihear" => {
          :abbreviations => ["pr.h", "ph", "p.h"],
          :expected_city => "Choam Khsant",
          :expected_latitude => 14.00857970,
          :expected_longitude => 104.84546190
        },

        "prey veaeng" => {
          :abbreviations => ["pr.v", "pv", "p.v", "prey veng"],
          :expected_city => "Smaong Khang Tboung Commune",
          :expected_latitude => 11.3802442,
          :expected_longitude => 105.5005483
        },

        "rotanak kiri" => {
          :abbreviations => ["r.r", "rr", "rk", "r.k", "ratanakiri"],
          :expected_city => "Andoung Meas",
          :expected_latitude => 13.85766070,
          :expected_longitude => 107.10119310
        },

        "krong preah sihanouk" => {
          :abbreviations => ["k.som", "k.saom", "s.v", "sihanoukville", "kampong som", "kampong saom", "kompong som", "kompong saom"],
          :expected_city => "Tuek Thla",
          :expected_latitude => 10.7581899,
          :expected_longitude => 103.8216261
        },

        "stueng traeng" => {
          :abbreviations => ["s.t", "st", "stung treng"],
          :expected_city => "Krong Stung Treng",
          :expected_latitude => 13.576473,
          :expected_longitude => 105.9699878
        },

        "svaay rieng" => {
          :abbreviations => ["sv.r", "svay rieng"],
          :expected_city => "Svay Rieng",
          :expected_latitude => 11.0877866,
          :expected_longitude => 105.800951
        },

        "taakaev" => {
          :abbreviations => ["tk", "t.k", "takeo"],
          :expected_city => "Doun Kaev",
          :expected_latitude => 10.9321519,
          :expected_longitude => 104.798771
        },

        "otdar mean chey" => {
          :abbreviations => ["o.chey", "om", "o.m", "oddar meanchey"],
          :expected_city => "Krong Samraong",
          :expected_latitude => 14.17171950,
          :expected_longitude => 103.63627150
        },

        "krong kep" => {
          :abbreviations => ["kep"],
          :expected_city => "ឃុំពងទឹក",
          :expected_latitude => 10.536089,
          :expected_longitude => 104.3559158
        },

        "krong pailin" => {
          :abbreviations => ["pl", "p.l", "pailin"],
          :expected_city => "Krong Pailin",
          :expected_latitude => 12.8539496,
          :expected_longitude => 102.6083506
        },

        "kampong chaam" => {
          :abbreviations => ["k.cham", "kc", "k.c"],
          :expected_city => "Tbuong Kmoum",
          :expected_latitude => 12.07699250,
          :expected_longitude => 105.68817880
        },

        "kampong chhnang" => {
          :abbreviations => ["k.chhnang", "kn", "k.n"],
          :expected_city => "Krong Kampong Chhnang",
          :expected_latitude => 12.250,
          :expected_longitude => 104.666667
        },

        "kampong spueu" => {
          :abbreviations => ["k.speu", "ks", "k.s", "kampong speu"],
          :expected_city => "Thpong",
          :expected_latitude => 11.6155109,
          :expected_longitude => 104.3791912
        },

        "kampong thum" => {
          :abbreviations => ["k.thom", "kt", "k.t", "kampong thom"],
          :expected_city => "Prasat Sambour",
          :expected_latitude => 12.90616,
          :expected_longitude => 105.2194808
        },

        "kampot" => {
          :abbreviations => ["k.pot", "kp", "k.p"],
          :expected_city => "Tuek Chhou",
          :expected_latitude => 10.7412089,
          :expected_longitude => 104.1930918
        },

        "kandaal" => {
          :abbreviations => ["kd", "k.d", "kandal", "kondal"],
          :expected_city => "Kandal",
          :expected_latitude => 11.4573319,
          :expected_longitude => 104.693403
        },

        "kaoh kong" => {
          :abbreviations => ["kk", "k.k", "koh kong"],
          :expected_city => "Koh Kong District",
          :expected_latitude => 11.5762804,
          :expected_longitude => 103.3587288
        },

        "ខ្ងុំចង់ដីង អ្នកជានរណា" => {
          :expected_city => nil,
          :expected_latitude => nil,
          :expected_longitude => nil
        },
      }
    end

    describe "#locate!" do
      it "should determine the correct location and city from the address" do
        assert_locate!(:kh, address_examples)
      end
    end
  end
end
