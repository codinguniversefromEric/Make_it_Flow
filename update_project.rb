require 'xcodeproj'

project_path = '/Users/giyoshimiken/Documents/Flow_1/Flow_1.xcodeproj'
project = Xcodeproj::Project.open(project_path)

main_group = project.main_group.find_subpath('Flow_1', true)
folders = ['App', 'Views', 'ViewModels', 'Core', 'Engines', 'DataModels', 'Store']

folders.each do |folder|
  # Create group
  group = main_group[folder] || main_group.new_group(folder, folder)
  
  # Find all files in the physical directory
  Dir.glob("/Users/giyoshimiken/Documents/Flow_1/Flow_1/#{folder}/*.swift").each do |file|
    basename = File.basename(file)
    
    # Find existing reference by basename
    file_ref = project.files.find { |f| f.path && File.basename(f.path) == basename }
    
    if file_ref
      # Move the reference to the new group
      file_ref.move(group)
      # Update its path relative to the new group
      file_ref.set_path(basename)
      puts "Moved #{basename} to #{folder}"
    else
      puts "Warning: Could not find existing reference for #{basename}"
    end
  end
end

project.save
puts "Successfully updated Xcode project."
