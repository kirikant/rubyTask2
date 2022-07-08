require 'open-uri'
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

  def initialize
  end

  def self.instance
    return @instance if @instance

    @instance_mutex.synchronize do
      @instance ||= new
    end

    @instance
  end

  def get_category_info(url, file_name)
    page_counter = 1

    while true do
      threads = []
      html = URI.open(url + "&p=#{page_counter}")
      base = html.base_uri

      current_url = Addressable::URI.parse(url + "&p=#{page_counter}")
      category_page = Nokogiri::HTML(html)

      if current_url.to_s.split("p=")[1].eql?(base.to_s.split("p=")[1]) || page_counter == 1

        puts "parsing page number #{page_counter}"
        products = category_page.xpath('//div[@class="main_content_area"]//div[@class="columns-container wide_container"]
    //div[@class="pro_outer_box"]')

        products_hash = get_href_title(products)
        products_packages = get_packages_prices(products_hash)
        combine_info(products_hash, products_packages, "#{file_name}", page_counter)

        page_counter = page_counter + 1

      else
        break
      end

    end

  end

  private

  def get_href_title(products)
    threads = []
    package_refs = []

    titles_hash = Hash.new
    image_refs_hash = Hash.new

    products_info = products.xpath('//a[@class=
"product_img_link pro_img_hover_scale product-list-category-img"]')

    puts "getting links of products packages"

    products_info.xpath('@href').each {
      |href|
      package_refs << href
    }

    puts "getting titles of products"
    threads << Thread.new do
      products_info.xpath('@title').each_with_index {
        |title, i|
        titles_hash[String.new(package_refs[i])] = String.new(title)
      }
    end

    puts "getting images of products"
    threads << Thread.new do
      products_info.xpath('//img[@class="replace-2x img-responsive front-image"]//@src').each_with_index {
        |image_ref, i|
        image_refs_hash[String.new(package_refs[i])] = String.new(image_ref)
      }
    end
    threads.each { |t| t.join }

    [titles_hash, image_refs_hash, package_refs]
  end

  def get_packages_prices(products_hash)
    puts "getting prices of products"
    threads = []
    ref_packages = Hash.new
    products_hash[2].each { |ref| threads << Thread.new {
      html = URI.open(ref)
      product_page = Nokogiri::HTML(html)
      html.close

      (product_page.xpath('//div[@class="main_content_area"]
       //div[@class="columns-container wide_container"]')).each { |packages|

        package_types = []
        package_prices = []

        packages.xpath('//span[@class="radio_label"]').each { |package|
          package_types << String.new(package)
        }
        packages.xpath('//span[@class="price_comb"]').each { |price|
          package_prices << String.new(price)
        }

        package_types.each_with_index { |package, i|
          ref_packages["#{package},#{package_prices[i]}"] = String.new(ref)
        }
      }
    }
    }
    threads.each { |t| t.join }
    ref_packages
  end

end
