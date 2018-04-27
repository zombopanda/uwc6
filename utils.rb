def time
  start = Time.now
  yield
  puts "\nTime elapsed #{(Time.now - start).round(2)} seconds."
end

def join_tables(tables)
  tables.map { |table| table.split("\n") }.transpose.map { |line| line.join('  ') }
end

def cut_string(str, length)
  if str.length > length
    "#{str[0..length]}..."
  else
    str
  end
end

class Logger
  def log(message)
    #print "[#{Time.now.strftime("%d/%m/%Y %H:%M:%S.%L")}] #{message}\n"
  end
end