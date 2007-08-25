# A simplistic interface to shell-based image processing. Pluggable, compact and WIN32-incompatible by
# design. Sort of like the Processors in attachment_fu but less. Less.
#
#    width, height = ImageProc.get_bounds("image.png")
#    thumb_filename = ImageProc.resize("image.png", "thumb.png", "50x50")
require 'open3'

class ImageProc
  class Error < RuntimeError; end;
  class FormatUnsupported < Error; end;

  class << self

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
      engine.send(*args)
    end
  end
  
  # Deprecated - pass the fitting as geometry string
  def resize(from, to, geom)
    to_width, to_height = geom.scan(/(\d+)/).flatten
    resize_fit_both(from, to, to_width, to_height).shift
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
  
  def resize_fit_height(from_path, to_path, height)
    validate_input_output_files(from_path, to_path)
    @target_w, @target_h = fit_sizes get_bounds(from_path), :height => height
    resetting_state_afterwards { process_exact }
  end
  
  private
    # cleanup any stale ivars
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

      raise Errno::ENOENT, "No such file or directory #{@source}" unless File.exist?(@source)
      raise Errno::ENOENT, "No such file or directory #{@dest}" unless File.exist?(File.dirname(@dest))
      raise Error, "This will overwrite #{@dest}" if File.exist?(@dest)
      # This will raise if anything happens
      @source_w, @source_h = get_bounds(from_path)
    end
    
    def integerize_values_of(h)
      h.each_pair{|k,v| h[k] = v.to_i}
    end
    
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
      
      # Nudge output values to pixels
      floats[0] = (floats[0].round > opts[:width] ? floats[0].ceil : floats[0].round) if opts[:width]
      floats[1] = (floats[1].round > opts[:height] ? floats[1].ceil : floats[1].round) if opts[:height]
      
      floats.map{|v| v.round }
    end
    
    def raise_on_err(cmd)
      inp, outp, err = Open3.popen3(cmd)
      error = err.read.to_s.strip

      raise Error, "Problem with #{@source}: #{error}" unless error.nil? || error.empty?
      result = outp.read.strip
      [inp, outp, err].map{|socket| begin; socket.close; rescue IOError; end }
      result
    end
    
end

class ImageProcConvert < ImageProc
  def process_exact
    raise_on_err("convert -resize #{@target_w}x#{@target_h}! #{@source} #{@dest}")
  end
  
  def get_bounds(of)
    raise_on_err("identify #{of}").scan(/(\d+)x(\d+)/)[0].map{|e| e.to_i }
  end
end

class ImageProcSips < ImageProc
  # -Z pixelsWH --resampleHeightWidthMax pixelsWH
  FORMAT_MAP = { ".tif" => "tiff", ".png" => "png", ".tif" => "tiff", ".gif" => "gif" }
  
  def process_exact
    fmt = detect_source_format
    raise_on_err("sips -s format #{fmt} --resampleHeightWidth #{@target_h} #{@target_w} #{@source} --out '#{@dest}'")
  end
  
  def get_bounds(of)
    raise_on_err("sips #{of} -g pixelWidth -g pixelHeight").scan(/(pixelWidth|pixelHeight): (\d+)/).to_a.map{|e| e[1].to_i}
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

require 'image_proc_test' if $0 == __FILE__