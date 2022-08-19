## List of All Known Code Contributors to Simplekiq

### Jack Noble (Doximity)
* Collaborated on initial concept
* Wrote the majority of the code as of initial release
* Helpful contributions to maintenance of specs, README, etc

### John Wilkinson (Doximity)
* Collaborated on initial concept
* Conducted the gem extraction and release

### Jason Hagglund (Doximity)
* Finagled a way into getting us the ability to specify `sidekiq-pro` as an explicit dependency despite it not being publicly available and without exposing it to the public in the process.

### Brian Dillard (Doximity)
* Added additional comment documentation
* Added support for `on_complete` batch callback support in `Simplekiq::BatchingJob`

### Austen Madden (Doximity)
* Fixed bug with batch statuses in callbacks for empty batches

### Tiffany Troha (Doximity)
* Added support for specifying `sidekiq_options` for the child job in `Simplekiq::BatchingJob`

### [Daniel Pepper](https://github.com/dpep)
* On request, graciously took down his unused `simplekiq` placeholder from rubygems so we could continue using the name :raised_hands:

### [Jeremy Smith](https://github.com/jeremysmithco)
* Helpfully and respectfully nudged us towards loosening our sidekiq version requirement
