require "yaml"
Dir.glob('./cassettes/*.yml').each do|f|
  next unless f =~ /[a-f0-9]{32}/
  d = YAML.load_file(f)
  d['http_interactions'].each do |r|
    r['request'].delete('headers')
    r['response'].delete('headers')
  end
  File.open(f, 'w') {|fw| fw.write(d.to_yaml) }
  #puts d.to_yaml
end
