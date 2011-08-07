module SimpleSearch
  DEFAULT_CONFIG = { :exact_match => [], 
                     :paginate => true, 
                     :page_name => 'page', 
                     :offset => 0,
                     :limit => 1000, 
                     :per_page => 20
                   }
  class Base
    def initialize(model_class, criteria, config={})
      @model_class = (model_class.is_a?(Symbol) || model_class.is_a?(String))? model_class.to_s.capitalize.constantize : model_class
      @table_name = @model_class.table_name
      @criteria = criteria.nil? ? {} : criteria
      sanitize_criteria
      @config = DEFAULT_CONFIG.merge(config)
      @joins = {}
    end
  
    def count
      @count || 0
    end

    def pages
      (count == 0)? 0 : (count / @config[:per_page].to_i + 1) 
    end

    def pages_for_select
      (1..pages).to_a
    end

    def add_conditions(h={})
      @criteria.merge!(h)
    end
  
    def conditions
      run_criteria
      @conditions
    end

    def joins
      run_criteria
      @joins_str
    end

    def run(option={})
      run_criteria
      if @config[:paginate]
        @count = @model_class.count({:select => "distinct #{@model_class.table_name}.#{@model_class.primary_key}", 
                                     :conditions => @conditions,
                                     :joins => @joins_str }
                 )
        offset = [((@page || 0) - 1) * @config[:per_page], 0].max
        limit = @config[:per_page]
      else
        offset = @config[:offset]
        limit = @config[:limit]
      end

      @model_class.all({:select => "distinct #{@model_class.table_name}.*", 
                        :conditions => @conditions,
                        :joins => @joins_str, 
                        :offset => @config[:offset],
                        :limit => @config[:limit] }.merge(option)
      )
    end

    private
  
    def method_missing(method, *args)
      method_str = method.to_s
      if method_str =~ /^([^=]+)=$/
        @criteria[$1.to_s] = args[0]
      else 
        @criteria[method_str]
      end
    end
  
    def make_joins
      @joins_str = ''
      @joins = @joins.values
      @joins.sort! {|a,b| a[0] <=> b[0]}
      @joins.each do |j|
        table = j[1]
        constrain = j[2]
        @joins_str << " inner join  #{table} on #{constrain}" 
      end
    end
  
    def run_criteria
      return @conditions unless @conditions.nil? 
      @criteria.each do |key, value|
        if @config[:page_name].to_s == key.to_s
          @page = value.to_i
          @criteria[key] = @page
        else
          parse_attribute(key, value)
        end
      end

      make_joins
    end

    def insert_condition(base_class, attribute, field, value)
      table = base_class.table_name
      key = "#{table}.#{field}"
  
      @conditions ||= []
      column = base_class.columns_hash[field.to_s]

      if !column.text? && value.is_a?(String)
        value = column.type_cast(value)
        @criteria[attribute] = value 
      end

      if value.nil?
        verb = 'is'
      elsif column.text? && ! @config[:exact_match].include?((@table_name == table)? field : key)
        verb = 'like'
        value = "%#{value}%"
      else
        verb = '='
      end

      if @conditions.size < 1
        @conditions[0] = "#{key} #{verb} ?"
        @conditions[1] = value
      else
        @conditions[0] += " and #{key} #{verb} ?"
        @conditions << value
      end
    end     
  
    def insert_join(base_class, asso_ref)
      base_table = base_class.table_name
      asso_table = asso_ref.klass.table_name
      
      @join_count ||= 0
      unless base_table == asso_table
        if @joins[asso_table].nil?
          @join_count += 1
          if asso_ref.belongs_to?
            @joins[asso_table] =[@join_count, asso_table, "#{base_table}.#{asso_ref.primary_key_name} = #{asso_table}.#{asso_ref.klass.primary_key}"]
          else
            @joins[asso_table] = [@join_count, asso_table, "#{base_table}.#{base_class.primary_key} = #{asso_table}.#{asso_ref.primary_key_name}"]
          end
        end
      end
    end
  
    def parse_attribute(attribute, value)
      unless attribute =~ /\./
        field = attribute
        insert_condition(@model_class, attribute, field, value)
        return
      end 

      association_fields = attribute.split(/\./)
      field = association_fields.pop

      base_class = @model_class
      while (association_fields.size > 0) 
        association_fields[0] = base_class.reflect_on_association(association_fields[0].to_sym)
        insert_join(base_class, association_fields[0])
        base_class = association_fields.shift.klass
      end

      insert_condition(base_class, attribute, field, value)
    end
  
    def sanitize_criteria
      @criteria.keys.each do |key|
        if @criteria[key].nil? || @criteria[key].blank?
          @criteria.delete(key)
        end
      end
    end
  end
end
