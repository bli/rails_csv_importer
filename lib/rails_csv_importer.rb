require 'faster_csv'

module Acts # :nodoc
  module RailsCsvImporter
    #
    # This class is the placeholder of methods common used.
    #
    class ValueMethods
      #
      # A value method that can be used on boolean type columns.
      # Accept 'yes' and 'no' instead of the default 'true" and 'false'
      #
      def self.yes_no_value_method
        lambda { |v, row, mapping|
          case v.downcase
            when 'yes' then true
            when 'no' then false
            else
              raise "Value must be Yes or No"
          end
        }
      end
    end

    #
    # The exception thrown when there are errors in the import.
    #
    class RailsCsvImportError < RuntimeError
      #
      # An array of errors occurred during the import.
      #
      # Each error is an array with two elements:
      #  1. Either a string of error message or the ActiveRecord::Errors object.
      #  2. An array of columns in the row that is associated with this error.
      #
      attr_reader :errors

      # An array of column headings.
      attr_reader :header_row

      # Number of rows already imported.
      attr_reader :num_imported

      def initialize(errors, header_row, num_imported) # :nodoc:
        @errors = errors
        @header_row = header_row
        @num_imported = num_imported
      end
    end

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods
      #
      # Called in a Rails model to bring it CSV Import funcationality provided in this gem.
      #
      def acts_as_rails_csv_importer
        class_eval do
          extend Acts::RailsCsvImporter::SingletonMethods
        end
      end
    end

    module SingletonMethods
      #
      # Import model data from csv content
      #
      # Options:
      #
      # * +import_config+ - specifies how the csv content is parsed.
      # * +content+ - the csv content in a string that can be parsed by FasterCSV
      # * +options+ - none for now
      #
      # Throws: +RailsCsvImportError+
      #
      # See +README.rdoc+ for details.
      #
      def import_from_csv(import_config, content, options = {})
        ic = Iconv.new('UTF-8', 'UTF-8')

        num_rows_saved=0
        errors = []
        header_row = []

        mapping = import_config[:mapping]
        # a hash for finding the key for a column heading quickly
        name_to_column_hash = mapping.keys.inject({}) { |acc, key|
           acc[translate_column(key, mapping).downcase] = key
           acc
        }

        self.transaction do
          all_rows = []
          # the column keys in the order of the column headings
          col_names = []
          row_num = 0
          col_num = 0

          # first phase: parse the csv and store the result in all_rows

          first_row = true
          begin
            FasterCSV.parse(content, :skip_blanks => true) do |row|
              row_num += 1
              col_num = 0
              row = row.map { |col| col_num += 1; ic.iconv(col) }
              if first_row == true
                header_row = row
                row.each { |column_name| col_names << name_to_column_hash[column_name.downcase] }
                first_row = false
              else
                all_rows << row
                row_hash = {}
                row.each_with_index { |column, x| row_hash[col_names[x]] = column if col_names[x] }
              end
            end
          rescue Iconv::IllegalSequence => ex
            all_rows = header_row = []
            errors << ["Invalid character encountered in row #{row_num}, column #{col_num} in the CSV file: #{ex.message}", []]
          rescue FasterCSV::MalformedCSVError => ex
            all_rows = header_row = []
            errors << ["Invalid CSV format: #{ex.message}", []]
          end

          # second phase: process the rows

          all_rows.each do |row|
            row_hash = {}
            row.each_with_index { |column, x| row_hash[col_names[x]] = column if col_names[x] }

            find_existing = import_config[:find_existing]
            if find_existing
              record = find_existing.call(row_hash) || self.new
            else
              record = self.new
            end

            begin
              row.each_with_index do |column, x|
                col_name = col_names[x]
                if col_name
                  col_config = mapping[col_name]
                  unless column.blank?
                    begin
                      # assign the correct value to the attribute according to the config
                      record[col_name] = if col_config[:value_method]
                        col_config[:value_method].call(column, row_hash, mapping)
                      elsif col_config[:record_method]
                        r = col_config[:record_method].call(column, row_hash, mapping)
                        raise "Unable to find referred record of value #{column}" if r.nil?
                        r.id
                      else
                        column
                      end
                    rescue Exception => e
                      raise "Failed to import column '#{header_row[x]}': #{e.message}"
                    end
                  end
                end
              end
            rescue Exception => e
              errors << [e.message, row]
              next
            end
            if record.save
              num_rows_saved += 1
            else
              errors << [record.errors, row]
            end
          end # all_rows

          raise RailsCsvImportError.new(errors, header_row, num_rows_saved) if errors.any? && !options[:partial_save]
        end # transaction

        raise RailsCsvImportError.new(errors, header_row, num_rows_saved) if errors.any? && options[:partial_save]

        num_rows_saved
      end

      #
      # Return the csv import template in a string.
      #
      # options:
      #
      # * +import_config+ - specifies how the csv content is parsed when importing from the template.
      #                     See +README.rdoc+ for details
      #
      def get_csv_import_template(import_config)
        mapping = import_config[:mapping]
        FasterCSV.generate do |csv|
          csv << mapping.keys.map { |key| translate_column(key, mapping) }
        end
      end

      private

      #
      # Translate a column key into its heading
      #
      # options:
      #
      # * +col+ - the key of the column
      # * +mapping+ - the mapping parameter in the config
      #
      def translate_column(col, mapping)
        if mapping[col][:name]
          mapping[col][:name]
        else
          if col[-3,3] == "_id"
            col = col[0, col.length - 3]
          end
          col.humanize
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, Acts::RailsCsvImporter) if defined?(ActiveRecord)

