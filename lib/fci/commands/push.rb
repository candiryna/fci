desc 'Read from Freshdesk and upload to Crowdin'
arg_name 'Describe arguments to push here'
command :push do |c|
  c.action do |global_options, options, args|
    config_file = '.config.yml'

    File.open(config_file, 'a+') do |f|
      config = YAML.load(f)
      unless config # config file empty
        config = {}
        # initialize empty config file
        f.write config.to_yaml
      end
    end
    
    # for store information about folders/articles ids
    config = YAML.load(File.open(config_file))

    # Source Category
    source_category_id = @fci_config['freshdesk_category'].to_i

    # Check if Category exists in Freshdesk
    source_category = FreshdeskAPI::SolutionCategory.find!(@freshdesk, id: source_category_id)
    raise('No such category') unless source_category.id == source_category_id

    # Get category's folders in Freshdesk
    folders = @freshdesk.solution_folders(category_id: source_category_id).all!

    folders_builder = []
    folders.each do |folder|
      folder_xml = build_folder_xml(folder)

      # write to config file
      unless folder_xml.nil?
        config[:folders] = [] unless config[:folders]
        unless config[:folders].detect { |f| f[:id] == folder.id }
          config[:folders] << { id: folder.id }
        end
      end

      unless folder_xml.nil?
        folders_builder << build_folder_hash(folder).merge({ xml: folder_xml })
      end
    end

    # Get folders articles
    articles_builder = []
    folders.each do |folder|
      articles = @freshdesk.solution_articles(category_id: source_category_id, folder_id: folder.id).all!

      articles.each do |article|
        article_xml = build_article_xml(article)

        # write to config file
        if config_folder = config[:folders].detect { |f| f[:id] == folder.id }
          (config_folder[:articles] ||= []) << { id: article.id }
        else
          abort 'No such folder!'
        end

        unless article_xml.nil?
          articles_builder << build_article_hash(article).merge({ xml:  article_xml })
        end
      end
    end


    crowdin_project_info = @crowdin.project_info

    # Creates xml files for folders and upload to Crowdin
    folders_builder.each do |folder|
      file_name = "folder_#{folder[:id]}.xml"

      o = File.new(file_name, 'w')
      o.write folder[:xml].to_xml
      o.close

      if crowdin_project_info['files'].detect { |file| file['name'] == file_name }
        puts "[Crowdin] Update file `#{file_name}`"
        @crowdin.update_file(
          files = [
            { dest: file_name, source: file_name, export_pattert: '/%two_letters_code%/%original_file_name%' }
          ], type: 'webxml'
        )
      else
        puts "[Crowdin] Add file `#{file_name}`"
        @crowdin.add_file(
          files = [
            { dest: file_name, source: file_name, export_pattert: '/%two_letters_code%/%original_file_name%' }
          ], type: 'webxml'
        )
      end
    end

    # Creates xml files for articles and upload to Crowdin
    articles_builder.each do |article|
      file_name = "article_#{article[:id]}.xml"

      o = File.new(file_name, 'w')
      o.write article[:xml].to_xml
      o.close

      if crowdin_project_info['files'].detect { |file| file['name'] == file_name }
        puts "[Crowdin] Update file `#{file_name}`"
        @crowdin.update_file(
          files = [
            { dest: file_name, source: file_name, export_pattert: '/%two_letters_code%/%original_file_name%' }
          ], type: 'webxml'
        )
      else
        puts "[Crowdin] Add file `#{file_name}`"
        @crowdin.add_file(
          files = [
            { dest: file_name, source: file_name, export_pattert: '/%two_letters_code%/%original_file_name%' }
          ], type: 'webxml'
        )

      end
    end

    # Write config file
    puts "Write config file"
    File.open(config_file, 'w') do |f|
      f.write config.to_yaml
    end

  end
end
