require 'test/unit'
require 'fileutils'


module ProcessorTest
  INPUTS = File.expand_path(File.dirname(__FILE__) + '/input')
  OUTPUTS = File.expand_path(File.dirname(__FILE__) + '/output')
  
  def setup
    Dir.glob(File.dirname(__FILE__) + '/output/*.*').map{ |e| FileUtils.rm e }

    @extensions = ["jpg", "png", "gif"]

    @horizontals =  @extensions.map { | ext | "horizontal.#{ext}" }
    @verticals =  @extensions.map { | ext | "vertical.#{ext}" }
    @horizontal_bounds = 780, 520
    @vertical_bounds = 466, 699
  end
  
  def test_get_bounds_raise_when_file_passed_does_not_exist
    assert_raise(ImageProc::Error) do
      @processor.get_bounds("/tmp/__non_existent/#{Time.now.to_i}")
    end
  end
  
  def test_get_bounds_raise_when_file_passed_is_not_an_image
    assert_raise(ImageProc::Error) do
      @processor.get_bounds(INPUTS + '/not.an.image.tmp')
    end
  end
  
  def test_properly_detects_bounds
    @horizontals.map do |file| 
      assert_equal @horizontal_bounds, @processor.get_bounds(INPUTS + "/" + file)
    end
    
    @verticals.map do |file| 
      assert_equal @vertical_bounds, @processor.get_bounds(INPUTS + "/" + file)
    end
  end
  
  def test_resize_raises_when_trying_to_overwrite
    assert_raise(ImageProc::Error) do
      @processor.resize INPUTS + '/' + @horizontals[0], INPUTS + '/' + @horizontals[0], "100x100"
    end
  end
  
  def test_exact_resize
    names = (@horizontals  + @verticals)
    sources = names.map{|file| INPUTS + "/" + file }

    sources.each_with_index do | source, index |
      @processor.resize_exact(source, OUTPUTS + '/' + names[index], 65, 65)
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [65, 65], get_bounds(result_p), "The image should have been resized exactly"
    end
  end
  
  # def test_exact_resize_raises_when_destination_directory_does_not_exist
  # def test_resize_fit
  # def test_resize_fit_width
  # def test_resize_fit_height
  
  private
    def get_bounds(of)
      if RUBY_PLATFORM =~ /darwin/i
        `sips #{of} -g pixelWidth -g pixelHeight`.scan(/(pixelWidth|pixelHeight): (\d+)/).to_a.map{|e| e[1]}
      else
        `identify #{of}`.scan(/(\d+)x(\d+)/)[0]
      end.map{|e| e.to_i}
    end
end

class TestGeometry < Test::Unit::TestCase
  def setup
    @x = ImageProc.new
    class << @x
      public :fit_sizes
    end
  end
  
  def test_fit_width
    bounds = [1024, 500]
    assert_equal [50, 24], @x.fit_sizes(bounds, :width => 50)

    bounds = [500, 1024]
    assert_equal [50, 102], @x.fit_sizes(bounds, :width => 50)
  end

  def test_fit_height
    bounds = [1024, 500]
    assert_equal [102, 50], @x.fit_sizes(bounds, :height => 50)

    bounds = [500, 1024]
    assert_equal [24, 50], @x.fit_sizes(bounds, :height => 50)
  end
  
  def test_fit_both
    bounds = [1024, 500]
    assert_equal [70, 34], @x.fit_sizes(bounds, :height => 70, :width => 70)

    bounds = [500, 1024]
    assert_equal [34, 70], @x.fit_sizes(bounds, :height => 70, :width => 70)
  end
  
  def test_we_grok_strings_too
    bounds = [1024, 500]
    assert_equal [70, 34], @x.fit_sizes(bounds, :height => "70", :width => "70")
  end

end

class TestImageProcSips < Test::Unit::TestCase
  def setup
    super
    @processor = ImageProcSips.new
    @horizontals.reject!{|e| e =~ /\.(png|gif)/}
    @verticals.reject!{|e| e =~ /\.(png|gif)/}
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
  
  include ProcessorTest
end

##class TestImageProcConvert < Test::Unit::TestCase
##  def setup
##    super
##    @processor = ImageProcConvert.new
##  end
##  
##  include ProcessorTest
##end