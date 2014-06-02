# Changelog

## 0.3.0 (2015-06-02)

[Compare changes in gem](https://github.com/taganaka/polipus/compare/0.2.2...0.3.0)

* Add `PolipusCrawler#add_to_queue` to add a page back to the queue
* Introduce new block `PolipusCrawler#on_page_error` which runs when there was an error (`Page#error`).
  For example a connectivity error.
  See `/examples/error_handling.rb`
* Add `Page#success?` which returns true if HTTP code is something in between 200 and 206.
* Polipus supports now `robots.txt` directives.
  Set the option `:obey_robots_txt` to `true`
  [#30](https://github.com/taganaka/polipus/pull/30)
* Add support for GZIP and deflate compressed HTTP requests
* Minor improvements to code style
