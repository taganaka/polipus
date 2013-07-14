require "yaml"
Dir.glob('./cassettes/Polipus_*.yml').each do|f|
  d = YAML.load_file(f)
  d['http_interactions'].each do |r|
    r['request'].delete('headers')
    r['response'].delete('headers')
  end
  File.open(f, 'w') {|fw| fw.write(d.to_yaml) }
  #puts d.to_yaml
end