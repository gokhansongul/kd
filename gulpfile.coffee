gulp       = require 'gulp'
gulpif     = require 'gulp-if'
gutil      = require 'gulp-util'
browserify = require 'browserify'
coffeeify  = require 'coffeeify'
rename     = require 'gulp-rename'
uglify     = require 'gulp-uglify'
stylus     = require 'gulp-stylus'
livereload = require 'gulp-livereload'
concat     = require 'gulp-concat'
minifyCSS  = require 'gulp-minify-css'
karma      = require 'gulp-karma'
clean      = require 'gulp-clean'
Q          = require 'q'
fs         = require 'fs'
http       = require 'http'
coffee     = require 'coffee-script'
argv       = require('minimist') process.argv
source     = require 'vinyl-source-stream'
gulpBuffer = require 'gulp-buffer'
ecstatic   = require 'ecstatic'
readdir    = require 'recursive-readdir'
{exec}     = require 'child_process'

pistachioCompiler = require 'gulp-pistachio-compiler'

STYLES_PATH   = require './src/themes/styl.includes.coffee'
COFFEE_PATH   = ['./src/components/**/*.coffee','./src/core/**/*.coffee','./src/init.coffee']
LIBS_PATH     = ['./libs/*.js']
TEST_PATH     = ['./src/**/*.test.coffee']
LIBS          = require './src/lib.includes.coffee'

buildDir      = argv.outputDir ? 'build'
version       = if argv.buildVersion then "#{argv.buildVersion}." else ''
useLiveReload = !!argv.liveReload
useUglify     = !!argv.uglify
useMinify     = !!(argv.minify ? yes)
karmaAction   = 'watch'
buildDocs     = !!argv.docs
buildPlay     = !!argv.play

# Helpers

log = (color, message) ->
  gutil.log gutil.colors[color] message

gulpBrowserify = (options, bundleOptions) ->
  options.extensions or= ['.coffee']
  bundleOptions or= {}
  b = browserify options
  b.transform coffeeify
  b.bundle bundleOptions

watchLogger = (color, watcher) ->
  watcher.on 'change', (event) ->
    log color, "file #{event.path} was #{event.type}"

liveReload = (stream)-> stream.pipe livereload()  if useLiveReload


# Build Tasks


gulp.task 'styles', ->

  gulp.src STYLES_PATH
    .pipe stylus()
    .pipe concat "kd.css"
    .pipe gulpif useMinify, minifyCSS()
    .pipe rename "kd.#{version}css"
    .pipe gulp.dest "#{buildDir}/css"
    .pipe gulpif useLiveReload, livereload()


gulp.task 'libs', ->

  gulp.src LIBS
    # .pipe gulpif useUglify, uglify()
    .pipe uglify()
    .pipe concat 'tmp'
    .pipe rename "kd.libs.#{version}js"
    .pipe gulp.dest "test"
    .pipe gulp.dest "#{buildDir}/js"
    .pipe gulpif useLiveReload, livereload()


gulp.task 'export', ->

  deferred = Q.defer()
  exec "cd ./src;sh exporter.sh > entry.coffee; cd ..", (err)->
    return deferred.reject err  if err
    deferred.resolve()

  return deferred.promise


gulp.task 'coffee', ['export'], ->

  entryPath = './src/entry.coffee'

  gulpBrowserify
      entries : entryPath
    .pipe source entryPath
    .pipe gulpBuffer()
    .pipe pistachioCompiler()
    .pipe gulpif useUglify, uglify()
    .pipe rename "kd.#{version}js"
    .pipe gulp.dest "#{buildDir}/js"
    .pipe gulpif useLiveReload, livereload()


# Build Playground

gulp.task 'play-styles', ['clean-play'], ->

  gulp.src ['./playground/main.styl']
    .pipe stylus()
    .pipe concat "kd.css"
    .pipe gulpif useMinify, minifyCSS()
    .pipe rename "main.css"
    .pipe gulp.dest "playground/css"
    .pipe gulpif useLiveReload, livereload()


gulp.task 'play-html', ->

  gulp.src './playground/index.html'
    .pipe gulpif useLiveReload, livereload()


gulp.task 'play-coffee', ['clean-play'], ->

  gulpBrowserify
      entries : ['./playground/main.coffee']
    .pipe source "main.js"
    .pipe gulp.dest "playground/js"
    .pipe gulpif useLiveReload, livereload()


gulp.task 'play', ['clean-play', 'play-html', 'play-styles', 'play-coffee'], ->


# Build docs

gulp.task 'docs-exec', ->

  deferred = Q.defer()
  exec "cd docs;mkdir js;mkdir css;cd ..", (err) ->
    return deferred.reject err  if err
    deferred.resolve()

  return deferred.promise


gulp.task 'docs-coffee', ['docs-exec'], ->

  gulpBrowserify
      entries : ['./docs/src/main.coffee']
    .pipe source 'main.js'
    .pipe gulp.dest 'docs/js'
    .pipe gulpif useLiveReload, livereload()


gulp.task 'docs-styles', ['docs-exec'],->

  gulp.src ['./docs/src/styl/main.styl']
    .pipe stylus()
    .pipe gulpif useMinify, minifyCSS()
    .pipe rename 'main.css'
    .pipe gulp.dest 'docs/css'
    .pipe gulpif useLiveReload, livereload()


gulp.task 'docs-html', ->

  gulp.src './docs/index.html'
    .pipe gulpif useLiveReload, livereload()


gulp.task 'docs', ['docs-exec', 'docs-html', 'docs-coffee', 'docs-styles']


# Build test suite

gulp.task 'coffee-test', ->

  stream = gulpBrowserify
      entries : './test/test.coffee'
    .pipe source "kd.test.js"
    .pipe gulp.dest 'test'
    .pipe gulpif useLiveReload, livereload()


gulp.task 'karma', ['coffee-test'], ->

  gulp.src ['./test/kd.*']
    .pipe karma
      configFile : 'karma.conf.js'
      action     : karmaAction


gulp.task 'sauce', ->
  gulp.src ['./test/kd.*']
    .pipe karma
      browsers   : [
        'sl_firefox_windows'
        'sl_chrome_windows'
        'sl_ie_9'
        'sl_ie_10'
      ]
      configFile : 'karma.conf.js'
      action     : 'run'



# Watch Tasks

gulp.task 'watch-test', ->

  watchLogger 'cyan', gulp.watch TEST_PATH, ['coffee-test']


gulp.task 'watch-coffee', ->

  watchLogger 'yellow', gulp.watch COFFEE_PATH, ['coffee']


gulp.task 'watch-libs', ->

  watchLogger 'yellow', gulp.watch LIBS_PATH, ['libs']


gulp.task 'watch-styles', ->

  watchLogger 'yellow', gulp.watch STYLES_PATH, ['styles']


gulp.task 'watch-playground', ->

  watchLogger 'blue', gulp.watch [
    './playground/**/*.coffee'
    './playground/**/*.html'
    './playground/**/*.styl'
  ], ['play']


gulp.task 'watch-docs', ->

  watchLogger 'blue', gulp.watch [
    './docs/src/**/*.coffee'
    './docs/src/**/*.styl'
    './docs/*.html'
  ], ['docs']


# Helper Tasks

gulp.task 'live', -> useLiveReload = yes


gulp.task 'run', -> karmaAction = 'run'


gulp.task 'clean', ->

  gulp.src ['build'], read : no
    .pipe clean force : yes


gulp.task 'clean-play', ->

  gulp.src ['playground/{css/js}'], read : no
    .pipe clean force : yes


# Aggregate Tasks

gulp.task 'compile', ['clean', 'styles', 'libs', 'coffee']

defaultTasks = [
  'live', 'compile', 'clean'
  'watch-styles', 'watch-coffee', 'watch-libs'
]

if buildDocs
  buildDir     = 'docs'
  defaultTasks = defaultTasks.concat ['docs', 'watch-docs']
else if buildPlay
  buildDir     = 'playground'
  defaultTasks = defaultTasks.concat ['play', 'watch-playground']


gulp.task 'default', defaultTasks , ->

  http.createServer ecstatic
      root        : "#{__dirname}/#{buildDir}"
      handleError : no
    .listen 8080

  log 'green', "HTTP server for #{buildDir} is ready at localhost:8080"


process.on 'uncaughtException', (err)->

  log 'red', "An error has occured: #{err.name}"
  console.error err
