require File.expand_path('../test_helper', __FILE__)

class I18nActiveRecordMissingTest < Test::Unit::TestCase
  class Backend < I18n::Backend::ActiveRecord
    include I18n::Backend::ActiveRecord::Missing
  end

  def setup
    I18n.backend.store_translations(:en, :bar => 'Bar', :i18n => { :plural => { :trans_keys => [:zero, :one, :other] } })
    I18n.backend = I18n::Backend::Chain.new(Backend.new, I18n.backend)
    I18n::Backend::ActiveRecord::Translation.delete_all
  end

  test "can persist interpolations" do
    translation = I18n::Backend::ActiveRecord::Translation.new(:trans_key => 'foo', :value => 'bar', :locale => :en)
    translation.interpolations = %w(count name)
    translation.save
    assert translation.valid?
  end

  test "lookup persists the trans_key" do
    I18n.t('foo.bar.baz')
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
    assert I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_trans_key('foo.bar.baz')
  end

  test "lookup does not persist the trans_key twice" do
    2.times { I18n.t('foo.bar.baz') }
    assert_equal 1, I18n::Backend::ActiveRecord::Translation.count
    assert I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_trans_key('foo.bar.baz')
  end

  test "lookup persists interpolation trans_keys when looked up directly" do
    I18n.t('foo.bar.baz', :cow => "lucy" )  # creates stub translation.
    translation_stub = I18n::Backend::ActiveRecord::Translation.locale(:en).lookup('foo.bar.baz').first
    assert translation_stub.interpolates?(:cow)
  end

  test "creates one stub per pluralization" do
    I18n.t('foo', :count => 999)
    translations = I18n::Backend::ActiveRecord::Translation.locale(:en).find_all_by_trans_key %w{ foo.zero foo.one foo.other }
    assert_equal 3, translations.length
  end

  test "creates no stub for base trans_key in pluralization" do
    I18n.t('foo', :count => 999)
    assert_equal 3, I18n::Backend::ActiveRecord::Translation.locale(:en).lookup("foo").count
    assert !I18n::Backend::ActiveRecord::Translation.locale(:en).find_by_trans_key("foo")
  end

  test "creates a stub when a custom separator is used" do
    I18n.t('foo|baz', :separator => '|')
    I18n::Backend::ActiveRecord::Translation.locale(:en).lookup("foo.baz").first.update_attributes!(:value => 'baz!')
    assert_equal 'baz!', I18n.t('foo|baz', :separator => '|')
  end

  test "creates a stub per pluralization when a custom separator is used" do
    I18n.t('foo|bar', :count => 999, :separator => '|')
    translations = I18n::Backend::ActiveRecord::Translation.locale(:en).find_all_by_trans_key %w{ foo.bar.zero foo.bar.one foo.bar.other }
    assert_equal 3, translations.length
  end

  test "creates a stub when a custom separator is used and the trans_key contains the flatten separator (a dot character)" do
    trans_key = 'foo|baz.zab'
    I18n.t(trans_key, :separator => '|')
    I18n::Backend::ActiveRecord::Translation.locale(:en).lookup("foo.baz\001zab").first.update_attributes!(:value => 'baz!')
    assert_equal 'baz!', I18n.t(trans_key, :separator => '|')
  end

end if defined?(ActiveRecord)

