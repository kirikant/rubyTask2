module CsvWorker
  def combine_info(products_hash, products_packages, file_name, page_counter)
    doc = CSV.open("#{file_name}.csv", 'a+')
    image_refs = products_hash[1]
    titles = products_hash[0]

    puts 'writing the data'
    doc << %w[title price image_link] if page_counter == 1
    products_packages.each do |key, value|
      array_csv = []
      array_csv << "#{titles[value]}(#{key.split(',')[0]})"
      array_csv << key.split(',')[1]
      array_csv << image_refs[value]

      doc << array_csv
    end

    doc.close

    puts 'complete'
  end
end
