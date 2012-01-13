#!/usr/bin/env ruby


    # == Synopsis
    #
    # rbator: ruby rasterbator
    #
    # == Usage
    #
    # rasterbator [OPTIONS] input_file
    #
    # --monochrome, -m
    #    use B&W mode, suitable for displays
    #
    # --invert-mono, -i
    #    use B&W mode with inverted tones, suitable for printing
    #
    # --step x, -s x:
    #    use x pixels as building block, image will scale x times in each dimension
    #
    # --alpha x, -a x:
    #    set alpha channel value to x (0..255) for the output.
    #
    # --output-file file, -o file
    #    output to file


require 'imlib2'
require 'getoptlong'
require 'rdoc/usage'
class Rbator

  attr_accessor :monochrome

  def initialize(in_file, opts={})
    opts = {:step => 5, :alpha => 255, :format => "png", :monochrome => false, :out_name => "out.png", :mono_invert => false}.merge opts

    @step = opts[:step]
    @alpha = opts[:alpha]
    @format = opts[:format]
    @monochrome = opts[:monochrome]
    @mono_invert = opts[:mono_invert]
    @img = Imlib2::Image.load in_file
    p "Loaded #{in_file}: #{@img.format}, #{@img.width}x#{@img.height}"
    @w = @img.width - @img.width % @step
    @h = @img.height - @img.height % @step
    @out_name = opts[:out_name]
    @out=nil
  end


  def get_value(x, y)
    pixels_r = []
    pixels_g = []
    pixels_b = []

    (x..(x+@step)).each do |i|
      (y..(y+@step)).each do |j|
        pix = @img.pixel i,j
        pixels_r << pix.r
        pixels_g << pix.g
        pixels_b << pix.b
      end
    end
    r = pixels_r.inject {|sum, n| sum+n} / @step**2
    r = 255 if r > 255

    g = pixels_g.inject {|sum, n| sum+n} / @step**2
    g = 255 if g > 255

    b = pixels_b.inject {|sum, n| sum+n} / @step**2
    b = 255 if b > 255

    fraction = (r+g+b) / (255*3.0)
    this_surface = (@mono_invert ? (@max_surface - (fraction * @max_surface)): fraction * @max_surface)
    radius = Math::sqrt(this_surface / Math::PI)
    return [radius, r, g, b] #unless @mono_invert
  end




  def rasterbate
    out = Imlib2::Image.new @w*@step, @h*@step
    out.format = @format
    out.fill_rect(0,0,@w*@step,@h*@step, Imlib2::Color::WHITE) if @mono_invert

  @max_surface = Math::PI * ((@step/2.0)**2)

  rx = (@step/2)..(@w-1)
  ry = (@step/2)..(@h-1)

  rx.step(@step) do |x|
    ry.step(@step) do |y|
      spot = get_value  x, y
      radius = spot.shift
      spot << @alpha
      color = @monochrome ? Imlib2::Color::WHITE : Imlib2::Color::RgbaColor.new(spot)
      out.fill_oval(x*@step +@step/2, y*@step+@step/2,radius*@step, radius*@step,  (@mono_invert ? Imlib2::Color::BLACK : color ))
    end
  end

  out.save_image @out_name
  @out = out
end

 def paginate(p_width, p_height, resolution)
   return unless @out

   x_pages = ((@out.width / resolution.to_f)/p_width).ceil
   y_pages = ((@out.height / resolution.to_f)/p_height).ceil

   puts "Outputting #{x_pages*y_pages} pages (#{x_pages}x#{y_pages})"

   effective_width = p_width*resolution
   effective_height = p_height*resolution

   (1..x_pages).each do |x|

     (1..y_pages).each do |y|
       puts "Paginating: page_#{x}_#{y}"

       x_src = (x-1)* effective_width
       y_src = (y-1)* effective_height
       width = ((x_src + effective_width) > @out.width) ? @out.width - x_src : effective_width
       height = ((y_src + effective_height) > @out.height) ? @out.height - y_src : effective_height

       outp = copy_img_rect_to_page(outp, x_src, y_src, width, height)
       outp.save_image "page_#{x}_#{y}#{@out_name}"
     end

   end

 end

 def copy_img_rect_to_page(dst, x_src, y_src, width, height)

   cropped = @out.crop(x_src,y_src,width, height)

   cropped.format = @out.format

   cropped
   # Imlib2::Image.draw_pixel_workaround = false
   # x_src = x_src.to_i
   # y_src = y_src.to_i
   # width = width.to_i
   # height = height.to_i
   # puts "copying #{x_src}..#{x_src+width}, #{y_src}..#{y_src+height}"

   # (x_src..(x_src+width)).each do |x|
   #   (y_src..(y_src+height)).each do |y|
   #     dst.draw_pixel(x - x_src, y - y_src, @out.pixel(x,y))
   #   end
   # end
end

end


opts = GetoptLong.new(
  ['--monochrome','-m', GetoptLong::NO_ARGUMENT],
  ['--mono-invert','-i', GetoptLong::NO_ARGUMENT],
  ['--output-file','-o', GetoptLong::REQUIRED_ARGUMENT],
  ['--step', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--alpha', '-a', GetoptLong::REQUIRED_ARGUMENT]
)


rasterbate_args = {}

opts.each do |opt, arg|
  case opt
  when '--monochrome'
    rasterbate_args[:monochrome] = true
  when '--mono-invert'
    rasterbate_args[:mono_invert] = true
  when '--output-file'
    rasterbate_args[:out_name] = arg
  when '--step'
    if(arg.to_i > 0)
      rasterbate_args[:step] = arg.to_i
    end
  when '--alpha'
    alpha = arg.to_i
    if(alpha >= 0 && alpha <=255)
      rasterbate_args[:alpha] = alpha
    end
  else
    puts "Unkown argument"
    RDoc::usage
    exit 1
  end
end

if ARGV.length != 1
  "Missing argument"
  RDoc::usage
  exit 1
end

in_name = ARGV.shift

rr = Rbator.new in_name, rasterbate_args

rr.rasterbate

