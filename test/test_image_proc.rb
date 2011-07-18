require 'test/unit'
require 'fileutils'
require 'resize_test_helper'
require 'image_proc'

# This will go away.
class TestQuickProcessViaClassWithGeomString < Test::Unit::TestCase
  def test_works
    source = File.dirname(__FILE__) + '/input/horizontal.jpg'
    dest = File.dirname(__FILE__) + '/output/resized.jpg'
    ImageProc.resize_with_geom_string(source, dest, "50x50")
    assert_equal [50,33], ImageProc.get_bounds(dest)
  ensure
    FileUtils.rm(dest) if File.exist?(dest)
  end
end

class TestQuickProcessWithOptions < Test::Unit::TestCase
  
  def test_resize_with_options
    source = File.dirname(__FILE__) + '/input/horizontal.jpg'
    dest = File.dirname(__FILE__) + '/output/resized.jpg'
    opts = {:height=>75, :fill=>true}
    begin
      assert_nothing_raised do
        path = ImageProc.resize(source, dest, opts)
        assert_equal dest, path
      end
    ensure
      File.unlink(dest) rescue nil
    end
  end
  
  def test_raises_on_invalid_options
    assert_raise(ImageProc::InvalidOptions) do
      source = File.dirname(__FILE__) + '/input/horizontal.jpg'
      dest = File.dirname(__FILE__) + '/output/resized.jpg'
      opts = {:too => 4, :doo => 10}
      ImageProc.resize(source, dest, opts)
    end
    
    assert_raise(ImageProc::InvalidOptions) do
      source = File.dirname(__FILE__) + '/input/horizontal.jpg'
      dest = File.dirname(__FILE__) + '/output/resized.jpg'
      opts = {}
      ImageProc.resize(source, dest, opts)
    end
  end
  
  def test_resize_with_nil_options
    source = File.dirname(__FILE__) + '/input/horizontal.jpg'
    dest = File.dirname(__FILE__) + '/output/resized.jpg'
    opts = {:height => 75, :fill => nil, :width => nil}
    begin
      assert_nothing_raised do
        path = ImageProc.resize(source, dest, opts)
        assert_equal dest, path
      end
    ensure
      File.unlink(dest) rescue nil
    end
  end
end

class TestEngineAssignmentSticks < Test::Unit::TestCase
  def test_foreign_engine_assignment_sticks
    dummy = "foobar"
    ImageProc.engine = dummy
    assert_equal dummy, ImageProc.engine
    ImageProc.engine = nil
  end
end

if RUBY_PLATFORM =~ /darwin/i
  class TestImageProcSips < Test::Unit::TestCase
    def setup
      super
      @processor = ImageProcSips.new
      @landscapes.reject!{|e| e =~ /\.(png|gif)/}
      @portraits.reject!{|e| e =~ /\.(png|gif)/}
    end
  
    def test_sips_does_not_grok_pngs
      assert_raise(ImageProc::FormatUnsupported) do
        @processor.resize(INPUTS + '/horizontal.gif', OUTPUTS + '/horizontal.gif', :width=> 100, :height => 100)
      end
    end
  
    def test_sips_does_not_grok_gifs
      assert_raise(ImageProc::FormatUnsupported) do
        @processor.resize(INPUTS + '/horizontal.png', OUTPUTS + '/horizontal.png', :width=> 100, :height => 100)
      end
    end
  
    include ResizeTestHelper
  end
end

if(`which convert`)
  class TestImageProcConvert < Test::Unit::TestCase
    def setup
      super
      ImageProcConvert.available?
      @processor = ImageProcConvert.new
    end
  
    include ResizeTestHelper
    
    def test_avail
      assert ImageProcConvert.available?
    end
  end
end

begin
  require 'RMagick'
  class TestImageProcRmagick < Test::Unit::TestCase
    def setup
      super
      @processor = ImageProcRmagick.new
    end
  
    include ResizeTestHelper
  end
rescue LoadError
end