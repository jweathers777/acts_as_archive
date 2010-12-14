require File.dirname(__FILE__) + '/acts_as_archive/gems'

ActsAsArchive::Gems.require(:lib)

require 'also_migrate'
require 'mover'

$:.unshift File.dirname(__FILE__)

require 'acts_as_archive/version'

class ActsAsArchive
  
  class <<self
    attr_accessor :configuration
    
    def find(from)
      from = [ from ] unless from.is_a?(::Array)
      (@configuration || []).select do |hash|
        if from[0].is_a?(::String)
          from.include?(hash[:from].table_name)
        else
          from.include?(hash[:from])
        end
      end
    end
    
    def move(config, where, merge_options={})
      config[:to].each do |to|
        options = config[:options].dup.merge(merge_options)
        if options[:conditions]
          options[:conditions] += " AND #{where}"
        elsif where
          options[:conditions] = where
        end
        config[:from].move_to(to, options)
      end
    end
  end
  
  module Base
    def self.included(base)
      base.extend ActMethods
    end

    module ActMethods
      def acts_as_archive(*args)
        return unless ActsAsArchive.find(self).empty?
        
        options = args.last.is_a?(::Hash) ? args.pop : {}
        options[:copy] = true
        options[:magic] = 'deleted_at' if options[:magic].nil?
        options[:add] = [[ options[:magic], :datetime ]]
        options[:ignore] = options[:magic]
        options[:timestamps] = false if options[:timestamps].nil?
        
        unless options[:archive]
          if args.empty?
            class_eval <<-EVAL
              class Archive < ActiveRecord::Base
                set_table_name "archived_#{self.table_name}"
              end
            EVAL
            args << self::Archive
          end
        
          args.each do |klass|
            klass.class_eval <<-EVAL
              record_timestamps = #{options[:timestamps].inspect}
              acts_as_archive(
                #{self},
                :archive => true,
                :magic => nil,
                :subtract => #{options[:magic] ? options[:magic].inspect : 'nil'}
              )
            EVAL
            self.reflect_on_all_associations.each do |association|
              puts association.klass.inspect
              if !ActsAsArchive.find(association.klass).empty? && association.options[:dependent]
                klass.send association.macro, association.name, association.options
              end
            end
            unless options[:migrate] == false
              self.also_migrate klass.table_name, options
            end
          end
        end
        
        ActsAsArchive.configuration ||= []
        ActsAsArchive.configuration << {
          :from => self,
          :to => args,
          :options => options
        }
      end
    end
  end
  
  module DatabaseStatements
    def self.included(base)
      unless base.included_modules.include?(InstanceMethods)
        base.send :include, InstanceMethods
        base.class_eval do
          unless method_defined?(:delete_sql_without_archive)
            alias_method :delete_sql_without_archive, :delete_sql
            alias_method :delete_sql, :delete_sql_with_archive
          end
        end
      end
    end
    
    module InstanceMethods
      def delete_sql_with_archive(sql, name = nil)
        from, where = /DELETE FROM (.+)/i.match(sql)[1].split(/\s+WHERE\s+/i, 2)
        from = from.gsub(/`/, '').split(/\s*,\s*/)
        
        ActsAsArchive.find(from).each do |config|
          ActsAsArchive.move(config, where)
        end
        
        delete_sql_without_archive(sql, name)
      end
      
      def migrate_from_acts_as_paranoid
        time = Benchmark.measure do
          ActsAsArchive.find(self).each do |config|
            ActsAsArchive.move(
              config,
              "#{config[:options][:magic]} IS NOT NULL",
              :migrate => true
            )
          end
        end
        $stdout.puts "-- #{self.class}.migrate_from_acts_as_paranoid"
        $stdout.puts "   -> #{"%.4fs" % time.real}"
      end
    end
  end
end

ActiveRecord::Base.send(:include, ActsAsArchive::Base)
ActiveRecord::ConnectionAdapters::DatabaseStatements.send(:include, ActsAsArchive::DatabaseStatements)