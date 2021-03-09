var gulp        = require('gulp');
var browserSync = require('browser-sync').create();
var sass        = require('gulp-sass');

const watchSass = require("gulp-watch-sass")

const sassConfig = {
    outputStyle: 'compressed'
};

const sassInput = [
    'static/scss/*.scss'
];
const sassOutput = gulp.dest("static/css")


// Compile sass into CSS & auto-inject into browsers
gulp.task('sass', function() {
    return gulp.src(sassInput)
        .pipe(sass(sassConfig))
        .pipe(sassOutput)
        .pipe(browserSync.stream());
});

gulp.task("sass:watch", () => watchSass(sassInput).pipe(sass(sassConfig))
  .pipe(sassOutput));


gulp.task('default', ['sass:watch']);