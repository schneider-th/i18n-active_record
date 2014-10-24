require 'i18n/backend/base'
require 'i18n/backend/active_record/translation'

module I18n
  module Backend
    class ActiveRecord
      autoload :Missing,     'i18n/backend/active_record/missing'
      autoload :StoreProcs,  'i18n/backend/active_record/store_procs'
      autoload :Translation, 'i18n/backend/active_record/translation'

      module Implementation
        include Base, Flatten

        def available_locales
          begin
            Translation.available_locales
          rescue ::ActiveRecord::StatementInvalid
            []
          end
        end

        def store_translations(locale, data, options = {})
          escape = options.fetch(:escape, true)
          flatten_translations(locale, data, escape, false).each do |trans_key, value|
            Translation.locale(locale).lookup(expand_trans_keys(trans_key)).delete_all
            Translation.create(:locale => locale.to_s, :trans_key => trans_key.to_s, :value => value)
          end
        end

      protected

        def lookup(locale, trans_key, scope = [], options = {})
          trans_key = normalize_flat_keys(locale, trans_key, scope, options[:separator])
          result = Translation.locale(locale).lookup(trans_key)

          if result.empty?
            nil
          elsif result.first.trans_key == trans_key
            result.first.value
          else
            chop_range = (trans_key.size + FLATTEN_SEPARATOR.size)..-1
            result = result.inject({}) do |hash, r|
              hash[r.trans_key.slice(chop_range)] = r.value
              hash
            end
            result.deep_symbolize_trans_keys
          end
        end

        # For a trans_key :'foo.bar.baz' return ['foo', 'foo.bar', 'foo.bar.baz']
        def expand_trans_keys(trans_key)
          trans_key.to_s.split(FLATTEN_SEPARATOR).inject([]) do |trans_keys, trans_key|
            trans_keys << [trans_keys.last, trans_key].compact.join(FLATTEN_SEPARATOR)
          end
        end
      end

      include Implementation
    end
  end
end

