# encoding: UTF-8

class FayeChannel < ActiveRecord::Base
  include IdNameCache; set_key_value :id, :name
  attr_accessible :id, :name
end
