## Copyright Ron Gejman, rog2021@med.cornell.edu
## v0.3 01/03/2012 

######
###### REPLACE THE FOLLOWING VALUES WITH YOUR USERNAME/PASSWORD/COURSE/LOCAL FOLDER STRUCTURE

USERNAME = ""
PASSWORD = ""
COURSES = ["Molecules, Genes & Cells", "Human Structure and Function", "Medicine, Patients and Society I", "Host Defenses", "Brain and Mind", "Medicine, Patients and Society II"]
FILE_DIRS = ["/Users/rgejman/Dropbox/M1/MGC", "/Users/rgejman/Dropbox/M1/HSF","/Users/rgejman/Dropbox/M1/MPS1", "/Users/rgejman/Dropbox/M1/HD", "/Users/rgejman/Dropbox/M2/BAM", "/Users/rgejman/Dropbox/M2/MPS2"]

######
######

require 'rubygems'
require 'mechanize'
require 'FileUtils'

REJECTED_LINKS = [/\(FNA\)\/Modules/, /\(FNA\)\/Glossary/, /Collaboration/, /Index/, /PBL Collaboration Space/, /Discussion Forum/, /MIRC/, /^\s*Up\s*$/, /My Notes/,/^\s*Previous\s*$/, /^\s*Next\s*$/, /Copyright Disclaimer/, /Video/, /\|/, /Calendar/, /Courseware/, /Evaluation/]

def is_downloadable_doc? (page)
  return false unless page.iframes.length > 0
  return false if page.iframes.first.uri.to_s =~ /Panopto/
  return false if page.iframes.first.uri.to_s =~ /javascript:/  
  return false unless page.iframes.first.content.respond_to? :links
  return false if page.iframes.first.content.links.first.to_s =~ /@/
  return true
end

def is_folder? (page)
  return true if page.iframes.length == 0
  return false
end

# recursive folder/doc identifier and downloader
def download_files(file_dir, agent, path, page)
  if is_folder? page
    links = page.links.reject {|l| REJECTED_LINKS.any? {|r| l.text =~ r } }
    for link in links
      new_path = page.title == "Course Materials" ? [] : path + [page.title.gsub("Folder: ","").gsub(":", " -").gsub("/","-").strip]
      download_files(file_dir, agent, new_path, link.click)
    end
  elsif is_downloadable_doc? page
    begin
      # we have a document—let's download it.
      return if page.iframes.first.content.links.empty?
      doc_link = page.iframes.first.content.links.first
      filename = doc_link.text.gsub(":", " -").gsub("/","-").strip
      enclosing_folder = "#{file_dir}/" + path.join("/")
      local_filepath = "#{enclosing_folder}/#{filename}"
      ## does this document already exist on the user's computer?
      unless File.exists? local_filepath
        puts "Downloading #{path.join('/')}/#{filename} to #{local_filepath}"
        uri = doc_link.uri
        return if uri.to_s =~ /javascript/ ## If we have a js link
        document = agent.get(uri).content
        FileUtils.mkdir_p enclosing_folder
        File.open(local_filepath, "w") do |f|
          f.write document
        end
      end
    rescue Mechanize::ResponseCodeError
      puts "404 Error: Could not find #{path.join('/')}/#{filename} on server"
    end
  end
end

for i in 0...COURSES.length
  puts "Doing #{COURSES[i]}"
  a = Mechanize.new { |agent|
    # pretend we're an ipad
    agent.user_agent_alias = 'Mac Safari'
    agent.follow_meta_refresh = true
  }

  a.get('https://courses.med.cornell.edu/home.asp') do |page|
    my_page = page.form_with(:action => '/signon/authenticate.asp') do |f|
      f.username  = USERNAME 
      f.password  = PASSWORD
    end.click_button
    home = a.get("https://courses.med.cornell.edu/profile/default.asp")
    course_page = home.links.find { |l| l.text.include? COURSES[i] }.click
    course_materials = course_page.links.find {|l| l.text == "Course Materials"}.click
    #traverse folder hierarchy to get all the files
    path = []
    download_files(FILE_DIRS[i], a, path, course_materials)
  end
end