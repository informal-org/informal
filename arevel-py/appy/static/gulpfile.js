const { src, dest, parallel, series, watch } = require('gulp');
const postcss = require('gulp-postcss');
const purgecss = require('gulp-purgecss');
const sass = require('gulp-sass');
const minifyCSS = require('gulp-csso');
const concat = require('gulp-concat');
const webpack = require('webpack')
const webpackConfig = require('./webpack.config.js')

async function build_css() {
  console.log("Build css");
  return src('css/*.css')
    .pipe(postcss())
    .pipe(minifyCSS())
    .pipe(dest('dist/static/css'))
}

async function build_sass() {
  console.log("Build sass");
  return src('css/**/*.scss')
  .pipe(sass().on('error',sass.logError))
  .pipe(postcss())
  .pipe(minifyCSS())
  .pipe(dest('dist/static/css'));
}

async function deploy_sass() {
  console.log("Deploy sass");
  await src('css/**/*.scss')
  .pipe(sass().on('error',sass.logError))
  .pipe(postcss())
  .pipe(minifyCSS())
  .pipe(dest('dist/static/css'));


  // Treat base separately

  return src('css/base.scss')
  .pipe(sass().on('error',sass.logError))
  .pipe(postcss())
  .pipe(purgecss({
    content: ['../templates/**/*.html']
  }))  
  .pipe(minifyCSS())
  .pipe(dest('dist/static/css'));

}

async function watch_css() {
  watch(['css/*.css'], build_css);  
  watch(['css/*.scss'], build_sass);
}

// For some reason, this is slower than doing it in webpack itself via npm, so we defer to that.
async function webpack_watch() {
  watch(['js/**/*.js'], webpack_assets);
}

async function watch_all() {
  watch_css();
}

async function deploy_css(cb) {
  console.log("Deploying css.")
  //   series('deploy_sass', 'build_css');
  await deploy_sass();
  await build_css();
  cb();
}

async function webpack_assets(cb, mode="development") {
  var devConfig = webpackConfig;
  devConfig["mode"] = mode;
  return new Promise((resolve, reject) => {
      webpack(devConfig, (err, stats) => {
          if (err) {
              return reject(err)
          }
          if (stats.hasErrors()) {
              return reject(new Error(stats.compilation.errors.join('\n')))
          }
          resolve()
      })
  })
}

// // exports.js = js;
exports.watch = watch_all;
exports.deploy_sass = deploy_sass;
exports.build_css = build_css;
exports.deploy = deploy_css;

// // exports.default = parallel(css, js);
// exports.default = parallel(css);