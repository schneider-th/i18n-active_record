require 'active_record'

module I18n
  module Backend
    # ActiveRecord model used to store actual translations to the database.
    #
    # This model expects a table like the following to be already set up in
    # your the database:
    #
    #   create_table :translations do |t|
    #     t.string :locale
    #     t.string :trans_trans_key
    #     t.text   :value
    #     t.text   :interpolations
    #     t.boolean :is_proc, :default => false
    #   end
    #
    # This model supports to named scopes :locale and :lookup. The :locale
    # scope simply adds a condition for a given locale:
    #
    #   I18n::Backend::ActiveRecord::Translation.locale(:en).all
    #   # => all translation records that belong to the :en locale
    #
    # The :lookup scope adds a condition for looking up all translations
    # that either start with the given trans_keys (joined by an optionally given
    # separator or I18n.default_separator) or that exactly have this trans_key.
    #
    #   # with translations present for :"foo.bar" and :"foo.baz"
    #   I18n::Backend::ActiveRecord::Translation.lookup(:foo)
    #   # => an array with both translation records :"foo.bar" and :"foo.baz"
    #
    #   I18n::Backend::ActiveRecord::Translation.lookup([:foo, :bar])
    #   I18n::Backend::ActiveRecord::Translation.lookup(:"foo.bar")
    #   # => an array with the translation record :"foo.bar"
    #
    # When the StoreProcs module was mixed into this model then Procs will
    # be stored to the database as Ruby code and evaluated when :value is
    # called.
    #
    #   Translation = I18n::Backend::ActiveRecord::Translation
    #   Translation.create \
    #     :locale => 'en'
    #     :trans_key    => 'foo'
    #     :value  => lambda { |trans_key, options| 'FOO' }
    #   Translation.find_by_locale_and_trans_key('en', 'foo').value
    #   # => 'FOO'
    class ActiveRecord
      class Translation < ::ActiveRecord::Base
        TRUTHY_CHAR = "\001"
        FALSY_CHAR = "\002"

        self.table_name = 'translations'

        serialize :value
        serialize :interpolations, Array

        class << self
          def locale(locale)
            where(:locale => locale.to_s)
          end

          alias_attribute :trans_key, :trans_trans_key

          def lookup(trans_keys, *separator)
            column_name = connection.quote_column_name('trans_key')
            trans_keys = Array(trans_keys).map! { |trans_key| trans_key.to_s }

            unless separator.empty?
              warn "[DEPRECATION] Giving a separator to Translation.lookup is deprecated. " <<
                "You can change the internal separator by overwriting FLATTEN_SEPARATOR."
            end

            namespace = "#{trans_keys.last}#{I18n::Backend::Flatten::FLATTEN_SEPARATOR}%"
            where("#{column_name} IN (?) OR #{column_name} LIKE ?", trans_keys, namespace)
          end

          def available_locales
            Translation.distinct(:locale).map { |t| t.locale.to_sym }
          end
        end

        def interpolates?(trans_key)
          self.interpolations.include?(trans_key) if self.interpolations
        end

        def value
          value = read_attribute(:value)
          if is_proc
            Kernel.eval(value)
          elsif value == FALSY_CHAR
            false
          elsif value == TRUTHY_CHAR
            true
          else
            value
          end
        end

        def value=(value)
          if value === false
            value = FALSY_CHAR
          elsif value === true
            value = TRUTHY_CHAR
          end

          write_attribute(:value, value)
        end
      end
    end
  end
end

