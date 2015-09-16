require 'shelljs/global'

bin = './node_modules/.bin'

task 'build', ->
  exec "#{bin}/browserify --debug -t coffeeify --extension='.coffee'
        js/*.coffee -o js/app.js"

