require 'open-uri'
require 'curb'
require 'csv'
require 'nokogiri/class_resolver'
require 'nokogiri'
require 'addressable/uri'
require 'thread'
require_relative 'csv_worker'

class Convertor
  include CsvWorker

  @instance_mutex = Mutex.new

  private_class_method :new

  def initialize; end

  def self.instance
    return @instance if @instance

    @instance_mutex.synchronize do
      @instance ||= new
    end

    @instance
  end

  def get_category_info(url, file_name)
    page_counter = 1
    marker = true
    while marker
      threads = []
      html = if page_counter == 1
               Curl.get(url)
             else
               Curl.get(url + "?p=#{page_counter}")
             end

      if !String.new(html.body_str).empty?

        category_page = Nokogiri::HTML(html.body_str)
        puts "parsing page number #{page_counter}"
        products = category_page.xpath('//div[@class="main_content_area"]
//div[@class="columns-container wide_container"]
    //div[@class="pro_outer_box"]')

        products_hash = get_href_title(products)
        products_packages = get_packages_prices(products_hash)
        combine_info(products_hash, products_packages, file_name.to_s, page_counter)

        page_counter += 1

      else
        marker = false
      end
    end
  end

  private

  def get_href_title(products)
    threads = []
    package_refs = []

    titles_hash = {}
    image_refs_hash = {}

    products_info = products.xpath('//a[@class=
"product_img_link pro_img_hover_scale product-list-category-img"]')

    puts 'getting links of products packages'

    products_info.xpath('@href').each do |href|
      package_refs << href
    end

    puts 'getting titles of products'
    threads << Thread.new do
      products_info.xpath('@title').each_with_index do |title, i|
        titles_hash[String.new(package_refs[i])] = String.new(title)
      end
    end

    puts 'getting images of products'
    threads << Thread.new do
      products_info.xpath('//img[@class="replace-2x img-responsive front-image"]//@src')
                   .each_with_index do |image_ref, i|
        image_refs_hash[String.new(package_refs[i])] = String.new(image_ref)
      end
    end
    threads.each(&:join)

    [titles_hash, image_refs_hash, package_refs]
  end

  def get_packages_prices(products_hash)
    puts 'getting prices of products'
    threads = []
    ref_packages = {}
    products_hash[2].each do |ref|
      threads << Thread.new do
        puts "ref: #{ref}"
        html = Curl.get(ref)
        product_page = Nokogiri::HTML(html.body_str)
        html.close

        product_page.xpath('//div[@class="main_content_area"]
         //div[@class="columns-container wide_container"]').each do |packages|

          package_types = []
          package_prices = []

          packages.xpath('//span[@class="radio_label"]').each do |package|
            package_types << String.new(package)
          end
          packages.xpath('//span[@class="price_comb"]').each do |price|
            package_prices << String.new(price)
          end

          package_types.each_with_index do |package, i|
            ref_packages["#{package},#{package_prices[i]}"] = String.new(ref)
          end
        end
      end
    end
    threads.each(&:join)
    ref_packages
  end
end
