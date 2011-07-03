require 'open3'

# A simplistic interface to shell-based image processing. Pluggable, compact and WIN32-incompatible by
# design. Sort of like the Processors in attachment_fu but less. Less.
#
#    width, height = ImageProc.get_bounds("image.png")
#    thumb_filename = ImageProc.resize("image.png", "thumb.png", :width => 50. :height => 50)
#
# The whole idea is: a backend does not have to support cropping (we don't do it), it has only to be able to resize,
# and a backend should have 2 public methods. That's the game.
class ImageProc
  VERSION = '1.0.0'

  class Error < RuntimeError; end
  class MissingInput < Error; end
  class NoDestinationDir < Error; end
  class DestinationLocked < Error; end
  class NoOverwrites < Error; end
  class FormatUnsupported < Error; end
  class InvalidOptions < Error; end
  
  HARMLESS = []
  class << self
    
    # Run a block without warnings
    def keep_quiet
      o = $VERBOSE
      begin
        $VERBOSE = nil
        yield
      ensure
        $VERBOSE = o
      end
    end
    
    # Assign a specific processor class
    def engine=(kls); @@engine = kls; end
  
    # Get the processor class currently assigned
    def engine; @@engine ||= detect_engine; @@engine; end
    
    # Tries to detect the best engine available
    def detect_engine
      if (`which convert` =~ /^\// )
        ImageProcConvert
      elsif RUBY_PLATFORM =~ /darwin/i
        ImageProcSips
      else
        raise "This system has no image processing facitilites that we can use. Time to compile RMagick or install a decent OS."
      end
    end
    
    # Qukckly get bounds of an image
    #   ImageProc.get_bounds("/tmp/upload.tif") #=> [100, 120]
    def get_bounds(of)
      engine.new.get_bounds(File.expand_path(of))
    end
    
    def method_missing(*args) #:nodoc:
      engine.new.send(*args)
    end
  end
  
  # Resizes with specific options passed as a hash, and return the destination path to the resized image
  #   ImageProc.resize "/tmp/foo.jpg", "bla.jpg", :width => 120, :height => 30
  def resize(from_path, to_path, opts = {})
    # raise InvalidOptions,
    #   "The only allowed options are :width, :height and :fill" if (opts.keys - [:width, :height, :fill]).any?
    raise InvalidOptions, "Geometry string is no longer supported as argument for resize()" if opts.is_a?(String)
    raise InvalidOptions, "Pass width, height or both" unless (opts.keys & [:width, :height]).any?
    opts.each_pair { |k,v|  raise InvalidOptions, "#{k.inspect} cannot be set to nil" if v.nil? }
    
    if opts[:width] && opts[:height] && opts[:fill]
      resize_fit_fill(from_path, to_path, opts[:width], opts[:height])
    elsif opts[:width] && opts[:height]
      resize_fit(from_path, to_path, opts[:width], opts[:height])
    elsif opts[:width]
      resize_fit_width(from_path, to_path, opts[:width])
    elsif opts[:height]
      resize_fit_height(from_path, to_path, opts[:height])
    else
      raise "This should never happen"
    end
    to_path
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
    @target_w, @target_h = fit_sizes(get_bounds(from_path), :height => height)
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
    
    disallow_nil_values_in(opts)
    integerize_values_of(opts)
    
    ratio = bounds[0].to_f / bounds[1].to_f
    floats = case (opts.keys & [:height, :width])
      when []
        raise "The options #{opts.inspect} do not contain proper bounds"
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
    force_keys!(opts, :width, :height)
    scale = [opts[:width].to_f / bounds[0], opts[:height].to_f / bounds[1]].sort.pop
    result = [bounds[0] * scale, bounds[1] * scale]
    result.map{|e| e.round}
  end
  
  private
    def force_keys!(in_hash, *keynames)
      unless (in_hash.keys & keynames).length == keynames.length
        raise Error, "This method requires #{keynames.join(', ')}" 
      end
    end
    
    def prevent_zeroes_in(floats)
      floats.map!{|f| r = f.round.to_i; (r.zero? ? 1 : r) }
    end
    
    def disallow_nil_values_in(floats)
      floats.each_pair{|k,v| floats.delete(k) if v.nil? }
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
      destdir = File.dirname(@dest)
      raise MissingInput, "No such file or directory #{@source}" unless File.exist?(@source)
      raise NoDestinationDir, "No destination directory #{destdir}" unless File.exist?(destdir)
      raise DestinationLocked, "Cannot write to #{destdir}" unless File.writable?(destdir)
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
        raise Error, "Problem: #{error}" unless error.nil? || error.empty?
      end
      [inp, outp, err].map{|socket| begin; socket.close; rescue IOError; end }
      result
    end
  
end

ImageProc.keep_quiet do
  class ImageProcConvert < ImageProc
    HARMLESS = [/unknown field with tag/]
    def process_exact
      wrap_stderr("convert -filter Gaussian -resize #{@target_w}x#{@target_h}! #{@source} #{@dest}")
    end
  
    def get_bounds(of)
      wrap_stderr("identify #{of}").scan(/(\d+)x(\d+)/)[0].map{|e| e.to_i }
    end
  end
end

ImageProc.keep_quiet do
  class ImageProcRmagick < ImageProc
    def get_bounds(of)
      run_require
      comp = wrap_err { Magick::Image.ping(of)[0] }
      res = comp.columns, comp.rows
      comp = nil; return res
    end

    def process_exact
      run_require
      img = wrap_err { Magick::Image.read(@source).first }
      img.scale(@target_w, @target_h).write(@dest)
      img = nil # deallocate the ref
    end
    private
      def run_require
        require 'RMagick' unless defined?(Magick)
      end
    
      def wrap_err
        begin
          yield
        rescue Magick::ImageMagickError => e
          raise Error, e.to_s
        end
      end
  end
end

ImageProc.keep_quiet do
  class ImageProcSips < ImageProc
    # -Z pixelsWH --resampleHeightWidthMax pixelsWH
    FORMAT_MAP = { ".tif" => "tiff", ".png" => "png", ".tif" => "tiff", ".gif" => "gif" }
    HARMLESS = [/XRefStm encountered but/, /CGColor/]
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
end