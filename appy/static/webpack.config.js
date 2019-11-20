const path = require('path');
const glob = require('glob');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const OptimizeCSSAssetsPlugin = require('optimize-css-assets-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');


// const Encore = require('@symfony/webpack-encore')

// Encore
//   .setOutputPath('public/build/')
//   .setPublicPath('/build')
//   .addStyleEntry('app', './css/app.css')
//   .enablePostCssLoader()

// module.exports = Encore.getWebpackConfig()


module.exports = (env, options) => ({
  optimization: {
    minimizer: [
      new UglifyJsPlugin({ cache: true, parallel: true, sourceMap: false }),
      new OptimizeCSSAssetsPlugin({})
    ]
  },
  entry: {
      './js/app.js': ['./js/app.js'].concat(glob.sync('./vendor/**/*.js'))
  },
  output: {
    filename: 'static/js/app.js',
    // path: path.resolve('dist/static/js/')
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: 'babel-loader'
        }
      },
      {
        test: /\.css$/,
        use: [
//           MiniCssExtractPlugin.loader, 
          'style-loader',
          { loader: 'css-loader', options: { importLoaders: 1 } },
          'postcss-loader'
        ],
        
      }
    ]
  },
  plugins: [
    // new MiniCssExtractPlugin({ filename: '../css/app.css' }),
    // new CopyWebpackPlugin([{ from: 'js/', to: 'dist/js/' }])
    new CopyWebpackPlugin([
      { from: 'images/', to: 'static/images/' },
      { from: 'css/', to: 'static/css/' },
  ])
  ]
});
