require 'test/unit'
require 'fileutils'
require 'resize_test_helper'
require 'image_proc'

class TestGeometryFitting < Test::Unit::TestCase
  def setup
    @x = ImageProc.new
    class << @x
      public :fit_sizes
    end
  end
  
  def test_fit_width
    bounds = [1024, 500]
    assert_equal [50, 24], @x.fit_sizes(bounds, :width => 50)
    assert_equal [50, 24], @x.fit_sizes(bounds, :width => 50, :height => nil)

    bounds = [500, 1024]
    assert_equal [50, 102], @x.fit_sizes(bounds, :width => 50)
  end
  
  def test_fit_width_should_not_modify_values_if_image_fits_already
    bounds = [100, 400]
    assert_equal bounds, @x.fit_sizes(bounds, :width => 100)
  end

  def test_fit_height_should_not_modify_values_if_image_fits_already
    bounds = [100, 400]
    assert_equal bounds, @x.fit_sizes(bounds, :height => 400)
  end
  
  def test_fit_height
    bounds = [1024, 500]
    assert_equal [102, 50], @x.fit_sizes(bounds, :height => 50)
    assert_equal [102, 50], @x.fit_sizes(bounds, :height => 50, :width => nil)

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
  
  def test_fit_groks_strings_too
    bounds = [1024, 500]
    assert_equal [70, 34], @x.fit_sizes(bounds, :height => "70", :width => "70")
  end
  
  def test_fit_rejects_nil_values
    bounds = [1024, 500]
    assert_equal [50, 24], @x.fit_sizes(bounds, :width => 50, :height => nil)
    assert_equal [102, 50], @x.fit_sizes(bounds, :height => 50, :width => nil)
  end

  def test_fit_nevere_produces_zeroes
    bounds = [1000, 20]
    assert_equal [20, 1], @x.fit_sizes(bounds, :width => 20, :height => 20)
  end
end

class TestGeometryFittingWithCrop < Test::Unit::TestCase
  def setup
    @x = ImageProc.new
  end
  
  def test_fit_suare_into_smaller_square_requires_no_cropping
    bounds = [100, 100]
    assert_equal [20, 20], @x.fit_sizes_with_crop(bounds, :width => 20, :height => 20)
  end

  def test_fit_landscape_into_square_will_slice_off_left_and_right
    bounds = [768, 575]
    assert_equal [27, 20], @x.fit_sizes_with_crop(bounds, :width => 20, :height => 20)

    bounds = [200, 40]
    assert_equal [100, 20], @x.fit_sizes_with_crop(bounds, :width => 20, :height => 20)
  end

  def test_fit_portrait_into_square_will_slice_off_top_and_bottom
    bounds = [576, 768]
    assert_equal [300, 400], @x.fit_sizes_with_crop(bounds, :width => 300, :height => 300)
  end

  def test_fit_portrait_into_portrait_will_resize
    bounds = [576, 768]
    assert_equal [200, 267], @x.fit_sizes_with_crop(bounds, :width => 200, :height => 210)
  end

  def test_fit_landscape_into_portrait_will_resize
    bounds = [768, 576]
    assert_equal [280, 210], @x.fit_sizes_with_crop(bounds, :width => 200, :height => 210)
  end
  
  def test_fit_with_crop_does_not_lie_when_small_floats_might_be_involved
   bounds = [20, 1000]
   assert_equal bounds, @x.fit_sizes_with_crop(bounds, :width => 20, :height => 20)
  end
  
  def test_fit_with_crop_should_not_overnudge
    bounds = [780, 520]
    assert_equal [375, 250], @x.fit_sizes_with_crop(bounds, :width => 260, :height => 250)
  end
end
