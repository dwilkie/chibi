# encoding: utf-8

require 'spec_helper'

describe Location do
  include LocationHelpers

  describe "Cambodia" do

    let(:address_examples) do
      {
        "phnom penh" => {
          :abbreviations => ["pp", "p.p"],
          :expected_city => "Phnom Penh",
          :expected_latitude => 11.558831,
          :expected_longitude => 104.917445
        },

        "siem reab" => {
          :abbreviations => ["sr", "s.r"],
          :expected_city => "Siem Reap",
          :expected_latitude => 13.3622222,
          :expected_longitude => 103.8597222
        },

        "baat dambang" => {
          :abbreviations => ["bb", "b.b"],
          :expected_city => "Battambang",
          :expected_latitude => 13.1,
          :expected_longitude => 103.2
        },

        "banteay mean chey" => {
          :abbreviations => ["b.chey", "bm", "b.m"],
          :expected_city => "Svay Chek",
          :expected_latitude => 13.66725960,
          :expected_longitude => 102.89750980
        },

        "kracheh" => {
          :abbreviations => ["kr.ch", "kr", "k.r"],
          :expected_city => "Kratie",
          :expected_latitude => 12.480,
          :expected_longitude => 106.030
        },

        "mondol kiri" => {
          :abbreviations => ["m.ri", "mk", "m.k"],
          :expected_city => "Pechr Chenda",
          :expected_latitude => 12.78794270,
          :expected_longitude => 107.10119310
        },

        "preah vihear" => {
          :abbreviations => ["pr.h", "pr", "p.r"],
          :expected_city => "Choam Khsant",
          :expected_latitude => 14.00857970,
          :expected_longitude => 104.84546190
        },

        "prey veaeng" => {
          :abbreviations => ["pr.v", "pv", "p.v"],
          :expected_city => "Prey Veaeng",
          :expected_latitude => 11.4851140,
          :expected_longitude => 105.3280980
        },

        "pousaat" => {
          :abbreviations => ["p.s", "ps"],
          :expected_city => "Pursat",
          :expected_latitude => 12.53333330,
          :expected_longitude => 103.91666670
        },

        "rotanak kiri" => {
          :abbreviations => ["r.r", "rr", "rk", "r.k"],
          :expected_city => "Ta Veaeng",
          :expected_latitude => 13.85766070,
          :expected_longitude => 107.10119310
        },

        "krong preah sihanouk" => {
          :abbreviations => ["k.som", "sv", "s.v"],
          :expected_city => "Prey Nob",
          :expected_latitude => 10.71623960,
          :expected_longitude => 103.77526340
        },

        "stueng traeng" => {
          :abbreviations => ["s.t", "st"],
          :expected_city => "Stung Treng",
          :expected_latitude => 13.79164340,
          :expected_longitude => 106.11105010
        },

        "svaay rieng" => {
          :abbreviations => ["sv.r", "sg", "s.g"],
          :expected_city => "Svay Rieng",
          :expected_latitude => 11.08333330,
          :expected_longitude => 105.80
        },

        "taakaev" => {
          :abbreviations => ["tk", "t.k"],
          :expected_city => "Takeo",
          :expected_latitude => 10.98333330,
          :expected_longitude => 104.78333330
        },

        "otdar mean chey" => {
          :abbreviations => ["o.chey", "om", "o.m"],
          :expected_city => "Samraong",
          :expected_latitude => 14.17171950,
          :expected_longitude => 103.63627150
        },

        "krong kep" => {
          :abbreviations => ["kep", "ke", "k.e"],
          :expected_city => "Kep",
          :expected_latitude => 10.51523510,
          :expected_longitude => 104.3326440
        },

        "krong pailin" => {
          :abbreviations => ["pl", "p.l"],
          :expected_city => "Sala Krau",
          :expected_latitude => 12.90929620,
          :expected_longitude => 102.66755750
        },

        "kampong chaam" => {
          :abbreviations => ["k.cham", "kc", "k.c"],
          :expected_city => "Krouch Chhmar",
          :expected_latitude => 12.07699250,
          :expected_longitude => 105.68817880
        },

        "kampong chhnang" => {
          :abbreviations => ["k.chhnang", "kn", "k.n"],
          :expected_city => "Kampong Chhnang",
          :expected_latitude => 12.250,
          :expected_longitude => 104.66666670
        },

        "kampong spueu" => {
          :abbreviations => ["k.speu", "ks", "k.s"],
          :expected_city => "Kampong Spoe",
          :expected_latitude => 11.47349210,
          :expected_longitude => 104.504360
        },

        "kampong thum" => {
          :abbreviations => ["k.thom", "kt", "k.t"],
          :expected_city => "Kampong Thom",
          :expected_latitude => 12.711970,
          :expected_longitude => 104.8886030
        },

        "kampot" => {
          :abbreviations => ["k.pot", "kp", "k.p"],
          :expected_city => "Kampot",
          :expected_latitude => 10.60630,
          :expected_longitude => 104.1819
        },

        "kandaal" => {
          :abbreviations => ["kd", "k.d"],
          :expected_city => "S'ang",
          :expected_latitude => 11.40010490,
          :expected_longitude => 105.12589550
        },

        "kaoh kong" => {
          :abbreviations => ["kk", "k.k"],
          :expected_city => "Koh Kong",
          :expected_latitude => 11.61666670,
          :expected_longitude => 102.98333330
        }
      }
    end

    describe "#locate!" do
      it "should determine the correct location and city from the address" do
        assert_locate!(:kh, address_examples)
      end
    end

    describe ".country_code" do
      it "should return the correct country code from a mobile number" do
        assert_country_code(:kh, "85512234456")
      end
    end
  end
end