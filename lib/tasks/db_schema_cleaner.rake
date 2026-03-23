if Rake::Task.task_defined?("db:schema:dump")
  Rake::Task["db:schema:dump"].enhance do
    file_path = Rails.root.join("db", "structure.sql")
    next unless File.exist?(file_path)

    sql = File.read(file_path)

    sql.gsub!(/^CREATE TABLE\s+(IF NOT EXISTS\s+)?['"]?\w+_fts_(data|idx|docsize|config|content)['"]?[\s\S]*?;\n*/i, "")
    sql.gsub!(/^INSERT INTO\s+['"]?\w+_fts_(data|idx|docsize|config|content)['"]?[\s\S]*?;\n*/i, "")

    File.write(file_path, sql)

    puts "✨ structure.sql ripulito dalle shadow tables (Kamal approved)!"
  end
end
