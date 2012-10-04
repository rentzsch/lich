desc 'Build'
task :build do
  puts "\n=== Building ==="
  
  system('cd cocoa && clang -o test/TestLichCocoa -Wno-unused-value -framework Foundation -I. -Ideps *.m deps/JRErr.m test/TestLichCocoa.m')
  puts '!!! FAILED !!!' if $?.exitstatus != 0
end

desc 'Test'
task :test => [:build] do
  puts "\n=== Testing ==="
  
  system('cocoa/test/TestLichCocoa lich-tests.json')
  puts '!!! FAILED !!!' if $?.exitstatus != 0
  
  system('rm cocoa/test/TestLichCocoa')
end

desc 'Clean up'
task :clean do
  puts "\n=== Cleaning ==="
  system('rm cocoa/test/TestLichCocoa')
end

task :default => [:clean, :test, :clean]