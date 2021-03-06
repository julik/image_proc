module ResizeTestHelper
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
    assert_raise(ImageProc::NoOverwrites) do
      @processor.resize INPUTS + '/' + @landscapes[0], INPUTS + '/' + @portraits[0], 
        :width => 100, :height => 100
    end
  end
  
  def test_resize_raises_when_source_missing
    missing_input = "/tmp/___imageproc_missing.jpg"
    assert !File.exist?(missing_input)
    assert_raise(ImageProc::MissingInput) do
      @processor.resize missing_input, OUTPUTS + '/zeoutput.jpg', 
        :width => 100, :height => 100
    end
  end
  
  def test_resize_raises_wheh_destination_dir_missing
    missing_output = "/tmp/___imageproc_missing/__missing.jpg"
    from = (INPUTS + '/' + @landscapes[0])
    
    assert !File.exist?(File.dirname(missing_output))
    assert_raise(ImageProc::NoDestinationDir) do
      @processor.resize from, missing_output, :width => 100, :height => 100
    end    
  end
  
  def test_resize_exact
    names = (@landscapes  + @portraits)
    sources = names.map{|file| INPUTS + "/" + file }

    sources.each_with_index do | source, index |
      assert_nothing_raised do
        path  = @processor.resize_exact(source, OUTPUTS + '/' + names[index], 65, 65)
        assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [65, 65], get_bounds(result_p), "The image should have been resized exactly"
    end
  end
  
  def test_resize_fitting_proportionally_into_square
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised do
        path  = @processor.resize_fit(source, OUTPUTS + '/' + name, 300, 300)
        assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [300, 200], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
    end
    
    with_each_vertical_path_and_name do | source, name |
      assert_nothing_raised { @processor.resize_fit(source, OUTPUTS + '/' + name, 300, 300) }
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [200, 300 ], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
    end
  end
  
  def test_fit_square_is_alias_for_proportional_resize
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised do
        path  = @processor.resize_fit_square(source, OUTPUTS + '/' + name, 300)
        assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [300, 200], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
    end
  end
  
  def test_resize_fitting_proportionally_into_portrait
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised do
        path, w, h  = @processor.resize_fit(source, OUTPUTS + '/' + name, 20, 100)
        assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end

      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [20, 13], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
    end
  end
  
  def test_resize_fitting_proportionally_into_landscape
     with_each_vertical_path_and_name do | source, name |
       assert_nothing_raised do
         path, w, h  = @processor.resize_fit(source, OUTPUTS + '/' + name, 100, 20)
         assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
       end
       
       result_p = OUTPUTS + '/' + File.basename(source)
       assert File.exist?(result_p), "#{result_p} should have been created"
       assert_equal [13, 20], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
     end
  end
  
  def test_resize_is_alias_for_fit_with_geometry_string
     with_each_horizontal_path_and_name do | source, name |
       assert_nothing_raised { @processor.resize(source, OUTPUTS + '/' + name, :width => 300, :height => 300) }
     
       result_p = OUTPUTS + '/' + File.basename(source)
       assert File.exist?(result_p), "#{result_p} should have been created"
       assert_equal [300, 200], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
     end
   
     with_each_vertical_path_and_name do | source, name |
       assert_nothing_raised do
          path = @processor.resize(source, OUTPUTS + '/' + name, :width => 300, :height => 300)
          assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result"
       end
       
       result_p = OUTPUTS + '/' + File.basename(source)
       assert File.exist?(result_p), "#{result_p} should have been created"
       assert_equal [200, 300 ], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into rect proortionally"
     end
  end
  
  def test_resize_fit_width
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised do
         path, w, h = @processor.resize_fit_width(source, OUTPUTS + '/' + name, 400)
         assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [400, 267], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been into width"
    end
    
    with_each_vertical_path_and_name do | source, name |
      assert_nothing_raised do
         path, w, h = @processor.resize_fit_width(source, OUTPUTS + '/' + name, 400)
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [400, 600 ], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been fit into width"
    end
  end
  
  def test_resize_fit_height
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised do
         path, w, h = @processor.resize_fit_height(source, OUTPUTS + '/' + name, 323)
         assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [485, 323], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been into width"
    end
    
    with_each_vertical_path_and_name do | source, name |
      assert_nothing_raised do
         path, w, h = @processor.resize_fit_width(source, OUTPUTS + '/' + name, 323)
         assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      
      assert File.exist?(result_p),
        "#{result_p} should have been created"
      assert_equal [323, 485], get_bounds(result_p), 
        "The image of #{get_bounds(source).join("x")} should have been fit into width"
    end
  end
  
  def test_resize_fit_fill
    with_each_horizontal_path_and_name do | source, name |
      assert_nothing_raised do
         path, w, h = @processor.resize_fit_fill(source, OUTPUTS + '/' + name, 260, 250)
         assert_equal OUTPUTS + '/' + File.basename(source), path, "The proc should return the path to the result as first ret"
      end
      
      result_p = OUTPUTS + '/' + File.basename(source)
      assert File.exist?(result_p), "#{result_p} should have been created"
      assert_equal [375, 250], get_bounds(result_p), "The image of #{get_bounds(source).join("x")} should have been into width"
    end
  end
  
  private
    def get_bounds(of)
      if RUBY_PLATFORM =~ /darwin/i
        `sips #{of} -g pixelWidth -g pixelHeight`.scan(/(pixelWidth|pixelHeight): (\d+)/).to_a.map{|e| e[1]}
      else
        `identify #{of}`.scan(/(\d+)x(\d+)/)[0]
      end.map{|e| e.to_i}
    end
    
    def with_each_vertical_path_and_name
      @portraits.each do | file |
        yield(INPUTS + "/" + file, file)
      end
    end
    
    def with_each_horizontal_path_and_name
      @landscapes.each do | file |
        yield(INPUTS + "/" + file, file)
      end
    end
    
end