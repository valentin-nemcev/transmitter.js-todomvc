/* global __dirname */

module.exports = {
  entry: './js/app.js',
  output: {
    path: __dirname,
    filename: 'bundle.js',
  },
  module: {
    loaders: [
      {
        test: /\.js$/,
        exclude: /node_modules\/(?!transmitter-framework)/,
        loader: 'babel-loader',
        query: {
          optional: ['runtime', 'es7.exportExtensions', 'es7.classProperties'],
          blacklist: ['es6.forOf', 'regenerator'],
        },
      },
    ],
  },
};
