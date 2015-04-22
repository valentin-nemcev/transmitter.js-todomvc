require 'shelljs/global'

bin = './node_modules/.bin'

task 'build', ->
  exec "#{bin}/browserify --debug -t coffeeify js/app.coffee -o js/app.js"

