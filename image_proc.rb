# A simplistic interface to shell-based image processing. Pluggable, compact and WIN32-incompatible by
# design. Sort of like the Processors in attachment_fu but less. Less.
#
#    width, height = ImageProc.get_bounds("image.png")
#    thumb_filename = ImageProc.resize("image.png", "thumb.png", "50x50")
#
# The whole idea is: a backend does not have to support cropping (we don't do it), it has only to be able to resize,
# and a backend should have 2 public methods. That's the game.
require 'open3'

class ImageProc
  class Error < RuntimeError; end
  class MissingInput < Error; end
  class NoDestinationDir < Error; end
  class NoOverwrites < Error; end
  class FormatUnsupported < Error; end;
  HARMLESS = []
  class << self
    def engine=(kls); @@engine = kls; end
    def engine; @@engine ||= detect_engine; end

    def detect_engine
      if RUBY_PLATFORM =~ /darwin/i
        ImageProcSips
      elsif (`which convert` =~ /^\// )
        ImageProcConvert
      else
        raise "This system has no image processing facitilites that we can use"
      end
    end
        
    def get_bounds(of)
      engine.new.get_bounds(File.expand_path(of))
    end
    
    def method_missing(*args) #:nodoc:
      engine.new.send(*args)
    end
  end
  
  # Deprecated - pass the fitting as geometry string. Will use proportional fitting.
  def resize(from, to, geom)
    to_width, to_height = geom.scan(/(\d+)/).flatten
    resize_fit_both(from, to, to_width, to_height).shift
  end
  alias_method :process, :resize
  
  # Resizes with specific options passed as a hash
  #   ImageProc.resize_with_options "/tmp/foo.jpg", "bla.jpg", :width => 120, :height => 30
  def resize_with_options(from_path, to_path, opts = {})
    raise Error, "Pass width, height or both" unless (opts.keys & [:width, :height]).any?
    if opts[:width] && opts[:height] && opts[:fill]
      resize_fit_fill(from_path, to_path, opts[:width], opts[:height])
    elsif opts[:width] && opts[:height]
      resize_fit(from_path, to_path, opts[:width], opts[:height])
    elsif opts[:width]
      resize_fit_width(from_path, to_path, opts[:width])
    else
      resize_fit_height(from_path, to_path, opts[:width])
    end
  end
  
  # Resize an image fitting the biggest side of it to the side of a square. A must for thumbs.
  def resize_fit_square(from_path, to_path, square_side)
    resize_fit_both(from_path, to_path, square_side, square_side)
  end

  # Resize an image fitting the boundary exactly. Will stretch and squash.
  def resize_exact(from_path, to_path, to_width, to_height)
    validate_input_output_files(from_path, to_path)
    @target_w, @target_h = to_width, to_height
    resetting_state_afterwards { process_exact }
  end

  # Resize an image fitting it into a rect.
  def resize_fit_both(from_path, to_path, to_width, to_height)
    validate_input_output_files(from_path, to_path)
    @target_w, @target_h = fit_sizes(get_bounds(from_path), :width => to_width, :height => to_height)
    resetting_state_afterwards { process_exact }
  end
  alias_method :resize_fit, :resize_fit_both

  # Resize an image fitting the biggest side of it to the side of a square. A must for thumbs.  
  def resize_fit_width(from_path, to_path, width)
    validate_input_output_files(from_path, to_path)
    
    @target_w, @target_h = fit_sizes get_bounds(from_path), :width => width
    resetting_state_afterwards { process_exact }
  end

  # Same as resize_fit_width  
  def resize_fit_height(from_path, to_path, height)
    validate_input_output_files(from_path, to_path)
    @target_w, @target_h = fit_sizes get_bounds(from_path), :height => height
    resetting_state_afterwards { process_exact }
  end

  # Will resize the image so that it's part always fills the rect of +width+ and +height+
  # It's recommended to then simply use CSS overflow to crop off the edges which are not necessary.
  # If you want more involved processing calculate the geometry directly.
  def resize_fit_fill(from_path, to_path, width, height)
    validate_input_output_files(from_path, to_path)
    @target_w, @target_h = fit_sizes_with_crop get_bounds(from_path), :height => height, :width => width
    resetting_state_afterwards { process_exact }
  end
  
  # Will fit the passed array of [input_width, input_heitght] proportionally and return an array of
  # [recommended_width, recommended_height] honoring the following parameters:
  #
  # :width - maximum width of the bounding rect
  # :height - maximum height of the bounding rect
  #
  # If you pass both the bounds will be fit into the rect having the :width and :height proportionally, downsizing the
  # bounds if necessary. Useful for calculating needed size before resizing.
  def fit_sizes(bounds, opts)
    integerize_values_of(opts)

    ratio = bounds[0].to_f / bounds[1].to_f
    keys = opts.keys & [:width, :height]
    floats = case keys
      when [:width]
        desired_w = opts[:width]
        [desired_w, desired_w / ratio]
      when [:height]
        desired_h = opts[:height]
        [desired_h * ratio, desired_h]
      else # both, use reduction
        smallest_side = [opts[:width], opts[:height]].sort.shift
        if bounds[0] > bounds[1] # horizontal
          fit_sizes bounds, :width => smallest_side
        else
          fit_sizes bounds, :height => smallest_side
        end
    end
    # Prevent zero results 
    prevent_zeroes_in(floats)

    # Nudge output values to pixels so that we fit exactly    
    floats[0] = opts[:width] if (opts[:width] && floats[0] > opts[:width])
    floats[1] = opts[:height] if (opts[:height] && floats[1] > opts[:height])
    floats
  end

  # Will fit the passed array of [input_width, input_heitght] to fill the whole rect and return an array of
  # [recommended_width, recommended_height] honoring the following parameters:
  #
  # :width - maximum width of the bounding rect
  # :height - maximum height of the bounding rect
  #
  # In contrast to fit_sizes it requires BOTH.
  #
  # It's recommended to clip the image which will be created with these bounds using CSS, as not all resizers support
  # cropping - and besides it's just too many vars.
  def fit_sizes_with_crop(bounds, opts)
    raise Error, "fit_sizes_with_crop requires both width and height" unless (opts.keys & [:width, :height]).length == 2
    scale = [opts[:width].to_f / bounds[0], opts[:height].to_f / bounds[1]].sort.pop
    result = [bounds[0] * scale, bounds[1] * scale]
    result.map{|e| e.round}
  end
  
  private
    def prevent_zeroes_in(floats)
      floats.map!{|f| r = f.round.to_i; (r.zero? ? 1 : r) }
    end
    
    # cleanup any stale ivars and return the path to result and the resulting bounds
    def resetting_state_afterwards
      begin
        @dest = @dest % [@target_w, @target_h] if File.basename(@dest).include?('%')
        kept = [@dest, @target_w, @target_h]; yield
      ensure
        @source, @dest, @source_w, @dest_w, @source_h, @dest_h = nil
      end
      kept
    end
    
    def validate_input_output_files(from_path, to_path)
      @source, @dest = [from_path, to_path].map{|p| File.expand_path(p) }

      raise MissingInput, "No such file or directory #{@source}" unless File.exist?(@source)
      raise NoDestinationDir, "No such file or directory #{@dest}" unless File.exist?(File.dirname(@dest))
      raise NoOverwrites, "This will overwrite #{@dest}" if File.exist?(@dest)
      # This will raise if anything happens
      @source_w, @source_h = get_bounds(from_path)
    end
    
    def integerize_values_of(h)
      h.each_pair{|k,v| v.nil? ? h.delete(k) : (h[k] = v.to_i)}
    end
    
    def wrap_stderr(cmd)
      inp, outp, err = Open3.popen3(cmd)
      error = err.read.to_s.strip
      result = outp.read.strip
      unless self.class::HARMLESS.select{|warning| error =~ warning }.any?
        raise Error, "Problem with #{@source}: #{error}" unless error.nil? || error.empty?
      end
      [inp, outp, err].map{|socket| begin; socket.close; rescue IOError; end }
      result
    end
  
end

class ImageProcConvert < ImageProc
  HARMLESS = [/unknown field with tag/]
  def process_exact
    wrap_stderr("convert -resize #{@target_w}x#{@target_h}! #{@source} #{@dest}")
  end
  
  def get_bounds(of)
    wrap_stderr("identify #{of}").scan(/(\d+)x(\d+)/)[0].map{|e| e.to_i }
  end
end

class ImageProcSips < ImageProc
  # -Z pixelsWH --resampleHeightWidthMax pixelsWH
  FORMAT_MAP = { ".tif" => "tiff", ".png" => "png", ".tif" => "tiff", ".gif" => "gif" }
  HARMLESS = [/XRefStm encountered but/]
  def process_exact
    fmt = detect_source_format
    wrap_stderr("sips -s format #{fmt} --resampleHeightWidth #{@target_h} #{@target_w} #{@source} --out '#{@dest}'")
  end
  
  def get_bounds(of)
    wrap_stderr("sips #{of} -g pixelWidth -g pixelHeight").scan(/(pixelWidth|pixelHeight): (\d+)/).to_a.map{|e| e[1].to_i}
  end
  
  private
    def detect_source_format
      suspected = FORMAT_MAP[File.extname(@source)]
      suspected =  (suspected.nil? || suspected.empty?) ? 'jpeg' : suspected
      case suspected
        when "png", "gif"
          raise FormatUnsupported, "SIPS cannot resize indexed color GIF or PNG images, call Apple if you want to know why"
      end
      return suspected
    end
end