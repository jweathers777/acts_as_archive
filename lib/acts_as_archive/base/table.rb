module ActsAsArchive
  module Base
    module Table

      def self.included(base)
        unless base.included_modules.include?(InstanceMethods)
          base.send :extend, ClassMethods
          base.send :include, InstanceMethods
          # Create archive table when Rails starts
          base.create_archive_table unless $TESTING
        end
      end

      module ClassMethods
        
        def create_archive_table
          if connection.table_exists?(table_name) && !connection.table_exists?("archived_#{table_name}")
            connection.execute(%{
              CREATE TABLE archived_#{table_name}
              ENGINE=InnoDB
                AS SELECT * from #{table_name}
                WHERE false;
            })
          end
          columns = connection.columns("archived_#{table_name}").collect(&:name)
          unless columns.include?('deleted_at')
            connection.add_column("archived_#{table_name}", 'deleted_at', :datetime)
          end
        end
      end

      module InstanceMethods
      end
    end
  end
end