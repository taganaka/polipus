# Changelog

## 0.3.1 (2015-06-17)

[Compare changes in gem](https://github.com/taganaka/polipus/compare/0.3.0...0.3.1)

* Major Code-Style changes and cleanup
  [#35](https://github.com/taganaka/polipus/pull/35)
* BugFix: proper initialization of internal_queue
  [#38](https://github.com/taganaka/polipus/pull/38)
* Better INT / TERM Signal handling [#34](https://github.com/taganaka/polipus/pull/34)

  New option added:
    ```ruby
    enable_signal_handler: true / false
    ```
  
* Zlib::GzipFile::Error handling
  [da3b927](https://github.com/taganaka/polipus/commit/da3b927acb1b50c26276ed458da0a365c22fd98b)
* Faster and easier overflow management
  [#39](https://github.com/taganaka/polipus/pull/39)

## 0.3.0 (2015-06-02)

[Compare changes in gem](https://github.com/taganaka/polipus/compare/0.2.2...0.3.0)

* Add `PolipusCrawler#add_to_queue` to add a page back to the queue
  [#24](https://github.com/taganaka/polipus/pull/24)
* Introduce new block `PolipusCrawler#on_page_error` which runs when there was an error (`Page#error`).
  For example a connectivity error.
  See `/examples/error_handling.rb`
  [#15](https://github.com/taganaka/polipus/issues/15)
* Add `Page#success?` which returns true if HTTP code is something in between 200 and 206.
* Polipus supports now `robots.txt` directives.
  Set the option `:obey_robots_txt` to `true`.
  See `/examples/robots_txt_handling.rb`
  [#30](https://github.com/taganaka/polipus/pull/30)
* Add support for GZIP and deflate compressed HTTP requests
  [#26](https://github.com/taganaka/polipus/pull/26)
* Minor improvements to code style
