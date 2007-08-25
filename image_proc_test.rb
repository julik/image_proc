require 'test/unit'
require 'fileutils'


module ProcessorTest
  INPUTS = File.expand_path(File.dirname(__FILE__) + '/input')
  OUTPUTS = File.expand_path(File.dirname(__FILE__) + '/output')
  
  def setup
    Dir.glob(File.dirname(__FILE__) + '/output/*.*').map{ |e| FileUtils.rm e }

    @extensions = ["jpg", "png", "gif"]
    @landscapes =  @extensions.map { | ext | "horizontal.#{ext}" }
    @portraits =  @extensions.map { | ext | "vertical.#{ext}" }
    @landscape_bounds = 780, 520
    @portraits_bounds = 466, 699
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
    @landscapes.map do |file| 
      assert_equal @landscape_bounds, @processor.get_bounds(INPUTS + "/" + file)
    end
    
    @portraits.map do |file| 
      assert_equal @portraits_bounds, @processor.get_bounds(INPUTS + "/" + file)
    end
  end
  
  def test_resize_raises_when_trying_to_overwrite
    assert_raise(ImageProc::Error) do
      @processor.resize INPUTS + '/' + @landscapes[0], INPUTS + '/' + @portraits[2], "100x100"
    end
  end
  
  def test_exact_resize
    names = (@landscapes  + @portraits)
    sources = names.map{|file| INPUTS + "/" + file }

    sources.each_with_index do | source, index |
      @processor.resize_exact(source, OUTPUTS + '/' + names[index], 65, 65)
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [65, 65], get_bounds(result_p), "The image should have been resized exactly"
    end
  end
  
  def test_resize_is_alias_for_fit_with_geometry_string
    names = (@landscapes  + @portraits)
    sources = names.map{|file| INPUTS + "/" + file }
    
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised { @processor.resize(source, OUTPUTS + '/' + name, "300x300") }
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [300, 200], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
    end
    
    with_each_vertical_path_and_name do | source, name |
      assert_nothing_raised { @processor.resize(source, OUTPUTS + '/' + name, "300x300") }
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [200, 300 ], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
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
    
    def with_each_vertical_path_and_name
      @landscapes.each do | file |
        yield(INPUTS + "/" + file, file)
      end
    end
    
    def with_each_horizontal_path_and_name
      @landscapes.each do | file |
        yield(INPUTS + "/" + file, file)
      end
    end
    
    def with_each_image_path_and_name
      with_each_horizontal_path_and_name { | path, name | yield path, name }
      with_each_vertical_path_and_name { | path, name | yield path, name }
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
    bounds = 1024, 500
    assert_equal [70, 34], @x.fit_sizes(bounds, :height => 70, :width => 70)

    bounds = 500, 1024
    assert_equal [34, 70], @x.fit_sizes(bounds, :height => 70, :width => 70)
    
    bounds = 780, 520
    assert_equal [120, 80], @x.fit_sizes(bounds, :height => 120, :width => 120)
  
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