require 'zlib'

# global hashes storing each packages installation

$installed_packages_hash = {}
$removed_packages_hash = {}
$upgraded_packages_hash  = {}
$purged_packages_hash = {}
$downgraded_packages_hash = {}
$reinstalled_packages_hash = {}

def get_section_info(section_string)
=begin
This method takes a section of the apt usage from apt-log in a single string and
extracts various info such as start time, end time, packages installed, upgraded,
removed, reinstalled etc and returns that info in a hash. The hash's keys are symbols
and values are string.
=end
  activity_info = {}
  begin
    # selects the line, split and extract date
    activity_info[:start_time] = section_string.scan(/^Start-Date:.*$/)[0].split(': ', 2).last
    activity_info[:end_time] = section_string.scan(/^End-Date:.*$/)[0].split(': ', 2).last # same as start_time
    activity_info[:command_line] = section_string.scan(/^Commandline:.*$/)[0].split(': ', 2).last

    # it selects the line and extracts the packages name and installation type
    activity_info[:installed] = section_string.scan(/^Install:.*$/)[0].to_s.split(': ', 2).last
    activity_info[:reinstalled] = section_string.scan(/^Reinstall:.*$/)[0].to_s.split(': ', 2).last
    activity_info[:removed] = section_string.scan(/^Remove:.*$/)[0].to_s.split(': ', 2).last
    activity_info[:purged] = section_string.scan(/^Purge:.*$/)[0].to_s.split(': ', 2).last
    activity_info[:upgraded] = section_string.scan(/^Upgrade:.*$/)[0].to_s.split(': ', 2).last
    activity_info[:downgraded] = section_string.scan(/^Downgrade:.*$/)[0].to_s.split(': ', 2).last
  rescue NoMethodError
    # This is for silently skipping the section with empty packages
  end
  activity_info
end

def extract_package_data(pkgs_info_str)
=begin
  This method takes a string which contains packages info involved in a single
  end apt-usage and returns an array of array containing individual package info extracted
=end
  return if pkgs_info_str.nil? # if nil return silently
  pkgs_info_str.gsub!(/\,/, '')

# separate them by looking at closed parenthesis.  and get the strings from array of array
  pkgs_info_str = pkgs_info_str.scan(/(.+?\(.+?\))/).collect { |package| package[0] }

# remove all `:`, `(` and `)` characters
  pkgs_info_str = pkgs_info_str.collect { |package| package.tr('()', '') }
  pkgs_info_str = pkgs_info_str.collect { |package| package.sub(':', ' ').strip }

  package_data  = pkgs_info_str.collect { |package| package.split }

  package_data #return
end

def store_into_hash(pkgs_array, storage_hash)
=begin
This method takes an array containing packages info which are itself array of values
and store that info into the hash provided by parameter
=end
  pkgs_array.each do |pkg|
    auto_value = pkg[3].nil? ? 'manual' : pkg[3]
    storage_hash[pkg[0]] = {arch: pkg[1], version: pkg[2], autovalue: auto_value }
  end
end

def print_info(pkgs_hash, type)
=begin
  This method takes a hash, containing info for packages and display them with a header
  The header type is determined by parameter 'type'
=end
  section_header = ''
  if type == :installed
    section_header = 'Installed packages information:'
  elsif type == :reinstalled
    section_header = 'Reinstalled packages information:'
  elsif type == :removed
    section_header = 'Removed packages information:'
  elsif type == :purged
    section_header = 'Removed packages information:'
  elsif type == :upgraded
    section_header = 'Upgraded packages information:'
  elsif type == :downgraded
    section_header = 'Downgraded packages information:'
  end
  puts section_header
  puts '=' * section_header.length # draw a line

  format = '%-40{name} %-10{arch} %-20{version} %-10{auto}'
  header = format % {name: 'PackageName', arch: 'Arch',
                     version: 'Version', auto: 'Auto/Manual'}
  puts header
  puts '-' * header.length # draw a dotted-line

  pkgs_hash.each do |package_name, package_info|
    puts format % {name: package_name, arch: package_info[:arch],
                   version: package_info[:version], auto: package_info[:autovalue]}
  end
  puts # a line break
end

def read_from_file()
  dir = '/var/log/apt/'
  gz_file_pattern = 'history.log.*.gz'
  content = '' #content of all logs

  # filenames in older first order
  files = Dir.glob(dir+gz_file_pattern).sort { |x, y| y <=> x }

  files.each do  |file|
    File.open(file) do |f|
      gz = Zlib::GzipReader.new(f)
      content += gz.read
      gz.close
    end
  end

  File.open(dir+'history.log') do |file|
    content += file.read
  end

  # File.open("apt-log-all.log", 'w') do |file|
  #   file.write(content)
  # end

  content #return
end


lines = read_from_file
sections = lines.split(/\n\n/) # divide into individual apt usage string
usage_data = []

sections.each do |section_string|
  usage_data << get_section_info(section_string)
end

usage_data.each do |section|

  if !section[:installed].nil?
    pkgs_arr = extract_package_data(section[:installed])
    store_into_hash(pkgs_arr, $installed_packages_hash)
  end
  if !section[:removed].nil?
    pkgs_arr = extract_package_data(section[:removed])
    store_into_hash(pkgs_arr, $removed_packages_hash)
  end
  if !section[:upgraded].nil?
    pkgs_arr = extract_package_data(section[:upgraded])
    store_into_hash(pkgs_arr, $upgraded_packages_hash)
  end
  if !section[:reinstalled].nil?
    pkgs_arr = extract_package_data(section[:reinstalled])
    store_into_hash(pkgs_arr, $reinstalled_packages_hash)
  end
  if !section[:downgraded].nil?
    pkgs_arr = extract_package_data(section[:downgraded])
    store_into_hash(pkgs_arr, $downgraded_packages_hash)
  end
  if !section[:purged].nil?
    pkgs_arr = extract_package_data(section[:purged])
    store_into_hash(pkgs_arr, $purged_packages_hash)
  end
end

print_info($installed_packages_hash, :installed)
print_info($reinstalled_packages_hash, :reinstalled)
print_info($removed_packages_hash, :removed)
print_info($purged_packages_hash, :purged)
print_info($upgraded_packages_hash, :upgraded)
print_info($downgraded_packages_hash, :downgraded)