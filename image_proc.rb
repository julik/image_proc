class ImageProc
  def self.process(from_path, to_path, geom_str)
    @@processor ||= ImageProcConvert
    @@processor.new.run(from_path, to_path, geom_str)
  end
  
  def run(from_path, to_path, geom_str)
    @x, @y = geom_str.scan(/(\d+)/).flatten
    @y ||= @x
    @source, @dest = [from_path, to_path].map{|p| File.expand_path(p) }
    raise Errno::ENOENT, "No such file or directory #{@source}" unless File.exist?(@source)
    raise Errno::ENOENT, "No such file or directory #{@dest}" unless File.exist?(File.dirname(@dest))
    raise "This will overwrite #{@dest}" if File.exist?(@dest)
    process
  end
  
  private
  
  def raise_on_err(cmd)
    stdin, stdout, stderr = Open3.popen3(cmd)
    error = stderr.read.to_s.strip
    raise "Could not convert the image using #{self.class}: #{error}" unless error.blank?
    return stdout.read.strip
  end
end

class ImageProcConvert < ImageProc
  def process
    raise_on_err("convert -scale #{@x}x#{@y} #{@source} #{@dest}")
  end
end

class ImageProcScience < ImageProc
  def process
    ImageScience.with_image(@source) do |img|
      img.thumbnail(@x) {|t| thumb.save @dest }
    end
  end
end

class ImageProcSips < ImageProc
  def process
    raise_on_err("sips -s format jpeg --resampleWidth #{@x} #{@source} --out #{@dest}")
  end
end