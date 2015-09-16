'use strict'


Transmitter = require 'transmitter'


class exports.VisibilityToggleVar extends Transmitter.Nodes.Variable

  constructor: (@$element) ->

  set: (state) -> @$element.toggle(!!state); this

  get: -> @$element.is(':visible')


class exports.ClassToggleVar extends Transmitter.Nodes.Variable

  constructor: (@$element, @class) ->

  set: (state) -> @$element.toggleClass(@class, !!state); this

  get: -> @$element.hasClass(@class)
