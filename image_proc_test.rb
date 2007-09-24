require 'test/unit'
require 'fileutils'
require 'resize_test_helper'
require 'image_proc'

class TestQuickProcessViaClass < Test::Unit::TestCase
  
  def test_works
    source = File.dirname(__FILE__) + '/input/horizontal.jpg'
    dest = File.dirname(__FILE__) + '/output/resized.jpg'
    assert_nothing_raised { ImageProc.resize(source, dest, "50x50") }
    FileUtils.rm dest
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
        @processor.resize(INPUTS + '/horizontal.gif', OUTPUTS + '/horizontal.gif', "100x100")
      end
    end
  
    def test_sips_does_not_grok_gifs
      assert_raise(ImageProc::FormatUnsupported) do
        @processor.resize(INPUTS + '/horizontal.png', OUTPUTS + '/horizontal.png', "100x100")
      end
    end
  
    include ResizeTestHelper
  end
end

if(`which convert`)
  class TestImageProcConvert < Test::Unit::TestCase
    def setup
      super
      @processor = ImageProcConvert.new
    end
  
    include ResizeTestHelper
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