class Record < ActiveRecord::Base
  
  belongs_to :belongs_to, :dependent => :destroy
  
  has_one :has_one, :dependent => :destroy
  
  has_many :has_manies, :dependent => :destroy
  
  has_many :has_many_through_throughs, :dependent => :destroy
  has_many :has_many_throughs, :dependent => :destroy, :through => :has_many_through_throughs
  
  has_one :has_one_through_through, :dependent => :destroy
  has_one :has_one_through, :dependent => :destroy, :through => :has_one_through_through
  
  acts_as_archive
end