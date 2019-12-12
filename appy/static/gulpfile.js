const { src, dest, parallel } = require('gulp');
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


// exports.js = js;
exports.css = css;

// exports.default = parallel(css, js);
exports.default = parallel(css);