module.exports = {
    transform: {
      '\\.js$': ['babel-jest', { configFile: './config/.babelrc' }]
    },
    roots: ['../']
  };
  