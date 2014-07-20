// Gulpfile.js
// Require the needed packages
var gulp        = require('gulp'),
    gutil       = require('gulp-util'),
    clean       = require('gulp-clean'),
    coffee      = require('gulp-coffee'),
    stylus      = require('gulp-stylus'),
    rename      = require('gulp-rename'),
    ejs         = require("gulp-ejs"),
    path        = require("path"),
    fs          = require('fs.extra'),
    del         = require('del'),
    runSequence = require('run-sequence');

var baseAppPath = path.join(__dirname,  'assets'),
    baseStaticPath = path.join(__dirname, 'App', 'generated'),
    baseJsPath = path.join(baseAppPath, 'js'),
    baseCssPath = path.join(baseAppPath, 'css');

var paths = {
  cleanPath      : path.join(baseStaticPath, '**', '*'),
  cssInput       : path.join(baseCssPath, 'main.styl'),
  cssOutput      : path.join(baseStaticPath, 'css'),
  coffeeInput    : path.join(baseJsPath, '**', '*.coffee'),
  coffeeOutput   : path.join(baseStaticPath, 'js'),
  ejsPath        : [path.join(baseAppPath, '**', '*.ejs')],
  assetsBasePath : baseAppPath,
  assetsPaths: [
    path.join(baseAppPath, 'img', '**', '*'),
    path.join(baseAppPath, 'fonts', '**', '*'),
    path.join(baseAppPath, '**', '*.html'),
    path.join(baseAppPath, '**', '*.json')
  ],
  assetsOutput: baseStaticPath
};

var watchPaths = {
  css: [
    path.join(baseCssPath, '**', '*.styl*'),
    baseCssPath, path.join('**', '*', '*.styl*')
  ],
  coffee: [path.join(baseJsPath, '**', '*.coffee')],
  assets: paths.assetsPaths,
  ejs: paths.ejsPath
}

var testFiles = [
  'generated/js/app.js',
  'test/client/*.js'
];


gulp.task('test', function() {
  // Be sure to return the stream
  return gulp.src(testFiles)
    .pipe(karma({
      configFile: 'karma.conf.js',
      action: 'run'
    }))
    .on('error', function(err) {
      // Make sure failed tests cause gulp to exit non-zero
      throw err;
    });
});


//
// Stylus
//


// Get and render all .styl files recursively
gulp.task('stylus', function () {
  return gulp.src(paths.cssInput)
    .pipe(stylus()
      .on('error', gutil.log)
      .on('error', gutil.beep))
    .pipe(gulp.dest(paths.cssOutput));

});


//
// Coffee
//

gulp.task('coffee', function() {
  return gulp.src(paths.coffeeInput)
    .pipe(coffee({bare: true})
      .on('error', gutil.log)
      .on('error', gutil.beep))
    .pipe(gulp.dest(paths.coffeeOutput));
});


//
// EJS
//

gulp.task('ejs', function() {
  return gulp.src(paths.ejsPath)
    .pipe(ejs()
      .on('error', gutil.log)
      .on('error', gutil.beep))
    .pipe(gulp.dest(paths.assetsOutput));
});


//
// Static Assets
//

gulp.task('assets', function() {
  return gulp.src(paths.assetsPaths, {base: paths.assetsBasePath})
    .pipe(gulp.dest(paths.assetsOutput)
      .on('error', gutil.log)
      .on('error', gutil.beep));
});


//
// Clean
//

gulp.task('clean', function() {
  return del(paths.cleanPath, { sync: true });
});


//
// Watch pre-tasks
//

gulp.task('watch-pre-tasks', function(callback) {
  runSequence('clean', ['coffee', 'stylus', 'assets', 'ejs', 'jade'], callback);
});


//
// Watch
//
gulp.task('watch', ['clean','stylus','coffee','assets','ejs'], function() {
  gulp.watch(watchPaths.css, ['stylus'])
    .on('error', gutil.log)
    .on('error', gutil.beep);
  gulp.watch(watchPaths.coffee, ['coffee'])
    .on('error', gutil.log)
    .on('error', gutil.beep);
  gulp.watch(watchPaths.assets, ['assets'])
    .on('error', gutil.log)
    .on('error', gutil.beep);
  gulp.watch(watchPaths.ejs, ['ejs'])
    .on('error', gutil.log)
    .on('error', gutil.beep);

});

gulp.task('default', ['stylus', 'coffee', 'assets', 'ejs']);
