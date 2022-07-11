require_relative 'convertor'
require_relative 'csv_worker'
require 'yaml'

params = YAML.load_file('info.yaml')
puts t1 = Time.now
Convertor.instance.get_category_info(params['link'], params['file_name'])
puts(Time.now - t1)
