const { src, dest, parallel, watch } = require('gulp');
const postcss = require('gulp-postcss');
const purgecss = require('gulp-purgecss');
const minifyCSS = require('gulp-csso');
const concat = require('gulp-concat');


function css() {
  return src('css/*.css')
    .pipe(postcss())
    .pipe(purgecss({
        content: ['../templates/**/*.html']
    }))
    .pipe(minifyCSS())
    .pipe(dest('dist/static/css'))
}


function watch_css() {
  watch(['css/*.css'], function(cb) {
    // Same as above, but without the purge because we may be using new html
    return src('css/*.css')
      .pipe(postcss())
      // .pipe(purgecss({
      //     content: ['../templates/**/*.html']
      // }))
      // .pipe(minifyCSS())
      .pipe(dest('dist/static/css'))
  })  
}

// // exports.js = js;
exports.watch = watch_css;

// // exports.default = parallel(css, js);
// exports.default = parallel(css);