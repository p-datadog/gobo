module.exports = function(api) {
  var validEnv = ['development', 'test', 'production']
  var currentEnv = api.env()
  var isTestEnv = api.env('test')
  var isProductionEnv = api.env('production')
  var isDevelopmentEnv = api.env('development')

  if (!validEnv.includes(currentEnv)) {
    throw new Error(
      'Please specify a valid `NODE_ENV` or ' +
        '`BABEL_ENV` environment variables. Valid values are "development", ' +
        '"test", and "production". Instead, received: ' +
        JSON.stringify(currentEnv) +
        '.'
    )
  }

  return {
    presets: [
      [
        require('@babel/preset-env').default,
        isTestEnv
          ? { targets: { node: 'current' } }
          : {
              forceAllTransforms: true,
              useBuiltIns: 'entry',
              corejs: 3,
              modules: false
            }
      ]
    ],
    plugins: [
      [
        require('@babel/plugin-transform-runtime').default,
        { helpers: false, regenerator: true, corejs: false }
      ]
    ].filter(Boolean)
  }
}
